locals {
  resource_tags = merge(var.common_tags, {
    Owner = var.owner
  })
}

data "aws_vpc" "db" {
  id = var.db_vpc_id
}

# 1. DB 보안 그룹
resource "aws_security_group" "db_sg" {
  name        = "${var.name_prefix}-db-sg"
  description = "Allow MariaDB 3306 traffic from EKS and Admin EC2"
  vpc_id      = var.db_vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.admin_sg_id]
  }
  ingress {
    description     = "Prometheus scrape from EKS - node_exporter"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  ingress {
    description     = "Prometheus scrape from EKS - mysqld_exporter"
    from_port       = 9104
    to_port         = 9104
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  # 443 = SSM/Secrets Manager/S3/ECR VPC Endpoint.
  # NAT/IGW route가 없는 private subnet에서는 이 규칙만으로 인터넷으로 나갈 수 없다.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS APIs through VPC endpoints"
  }

  # DNS는 VPC 내부 리졸버로만 나가면 충분하다.
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.db.cidr_block]
    description = "DNS (TCP) to in-VPC resolver"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.db.cidr_block]
    description = "DNS (UDP) to in-VPC resolver"
  }

  # lifecycle { prevent_destroy = true }

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}

# 2. DB 통신 룰
resource "aws_vpc_security_group_egress_rule" "admin_to_db_3306" {
  security_group_id            = var.admin_sg_id
  referenced_security_group_id = aws_security_group.db_sg.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  description                  = "Allow Admin EC2 outbound to new DB EC2"
}

# 3. DB 자격증명을 Secrets Manager에 저장한다 (H1 수정).
#    - SSM 문서 본문에는 secret 값이 아니라 secret '이름'만 들어간다.
#    - 인스턴스는 부팅/백업 시 런타임에 값을 조회한다.
#    dev 재적용 편의를 위해 recovery_window_in_days=0 으로 즉시 삭제 가능하게 둔다.
resource "aws_secretsmanager_secret" "db_app" {
  name                    = "${var.name_prefix}-db-app-password"
  description             = "MariaDB root/app password for ${var.name_prefix} DB EC2"
  recovery_window_in_days = 0
  tags                    = local.resource_tags
}

resource "aws_secretsmanager_secret_version" "db_app" {
  secret_id     = aws_secretsmanager_secret.db_app.id
  secret_string = var.db_app_password
}

resource "aws_secretsmanager_secret" "db_exporter" {
  name                    = "${var.name_prefix}-db-exporter-password"
  description             = "mysqld_exporter password for ${var.name_prefix} DB EC2"
  recovery_window_in_days = 0
  tags                    = local.resource_tags
}

resource "aws_secretsmanager_secret_version" "db_exporter" {
  secret_id     = aws_secretsmanager_secret.db_exporter.id
  secret_string = var.db_exporter_password
}

# 4. 데이터 보존을 위한 독립형 영구 EBS 볼륨 생성 및 결합
data "aws_subnet" "db" {
  id = var.db_private_subnet_id
}

resource "aws_ebs_volume" "db_data" {
  availability_zone = data.aws_subnet.db.availability_zone
  size              = var.db_data_volume_size
  type              = var.db_data_volume_type

  # lifecycle { prevent_destroy = true }

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-ebs-db-data"
  })
}

# 5. DB EC2 인스턴스.
#    완전 폐쇄망 구성을 위해 Docker/AWS CLI/cron/SSM Agent는 Golden AMI에 사전 설치한다.
resource "aws_instance" "db" {
  ami                    = var.db_ami_id
  instance_type          = "t3.medium"
  subnet_id              = var.db_private_subnet_id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  iam_instance_profile   = var.db_ec2_profile_name
  private_ip             = var.db_private_ip

  # disable_api_termination = true
  # lifecycle { prevent_destroy = true }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    # delete_on_termination = false
  }

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user_data_init.log|logger -t user-data -s 2>/dev/console) 2>&1
              echo "=== Golden AMI prerequisite validation ==="

              if ! id -u ssm-user &>/dev/null; then
                useradd -m ssm-user
                echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-user
                chmod 440 /etc/sudoers.d/ssm-user
              fi

              systemctl daemon-reload
              systemctl enable --now amazon-ssm-agent
              systemctl enable --now docker

              if systemctl list-unit-files | grep -q crond; then
                systemctl enable --now crond
              else
                systemctl enable --now cron
              fi

              usermod -aG docker ssm-user || true

              if command -v docker >/dev/null && command -v aws >/dev/null && command -v curl >/dev/null; then
                echo "SUCCESS" > /var/log/user_data_complete
                echo "=== Golden AMI prerequisite validation success ==="
              else
                echo "=== Golden AMI prerequisite validation FAILED: docker/aws/curl missing ==="
                exit 1
              fi
              EOF

  tags = merge(local.resource_tags, {
    Name = "${var.name_prefix}-ec2-db"
    Role = "Database-Container-Host"
  })
}

# 6. 인스턴스와 볼륨 결합 선언
resource "aws_volume_attachment" "db_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = aws_instance.db.id
}

# user_data에서 찍은 완료 도장 파일(/var/log/user_data_complete)이 나올 때까지 테라폼을 멈춰 세움
resource "null_resource" "wait_for_user_data" {
  depends_on = [
    aws_instance.db,
    aws_volume_attachment.db_data
  ]

  # M6: 인스턴스가 바뀌면 다시 대기하도록 한다.
  triggers = {
    instance_id                  = aws_instance.db.id
    bootstrap_prerequisite_token = var.bootstrap_prerequisite_token
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"] # M2: brace expansion이 필요하므로 bash 고정
    command     = <<BAR
      echo "=== Waiting for user_data execution to complete inside EC2 ==="
      for i in {1..30}; do
        STATUS=$(aws ssm send-command \
          --instance-ids "${aws_instance.db.id}" \
          --document-name "AWS-RunShellScript" \
          --parameters 'commands=["cat /var/log/user_data_complete"]' \
          --query "Command.Status" --output text 2>/dev/null)

        # SSM 명령어가 성공적으로 접수되고 파일이 조회되면 루프 탈출
        if [ "$STATUS" = "Success" ] || [ "$STATUS" = "Pending" ] || [ "$STATUS" = "InProgress" ]; then
          # 실제 커맨드 아이디 추적해서 완벽하게 끝났는지 한 번 더 정밀 검증
          CMD_ID=$(aws ssm send-command --instance-ids "${aws_instance.db.id}" --document-name "AWS-RunShellScript" --parameters 'commands=["test -f /var/log/user_data_complete && echo OK"]' --query "Command.CommandId" --output text)
          sleep 5
          RESULT=$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "${aws_instance.db.id}" --query "StandardOutputContent" --output text 2>/dev/null)
          if echo "$RESULT" | grep -q "OK"; then
            echo "=== user_data Verified Successfully! ==="
            exit 0
          fi
        fi
        echo "Waiting for user_data to finish packaging... ($i/30)"
        sleep 10
      done
      echo "Timeout waiting for user_data" && exit 1
BAR
  }
}

# 7. SSM 구동 문서 정의
#    - GitHub clone 대신 private S3 artifact에서 SQL을 내려받는다.
#    - public registry 대신 private ECR에 복제된 이미지만 pull한다.
#    - 비밀번호는 문서에 박지 않고 Secrets Manager에서 런타임 조회한다.
resource "aws_ssm_document" "run_mariadb" {
  name          = "${var.name_prefix}-run-mariadb-container"
  document_type = "Command"

  content = <<EOF
{
  "schemaVersion": "2.2",
  "description": "Deploy MariaDB and setup automation",
  "mainSteps": [
    {
      "action": "aws:runShellScript",
      "name": "runDockerMariaDB",
      "inputs": {
        "runCommand": [
          "#!/bin/bash",
          "set -euo pipefail",
          "exec > >(tee /var/log/user_data_delayed.log|logger -t delayed-proto -s 2>/dev/console) 2>&1",

          "echo '=== 0. Secrets Manager에서 자격증명 로딩 ==='",
          "DB_PW=$(aws secretsmanager get-secret-value --region ${var.region} --secret-id '${aws_secretsmanager_secret.db_app.name}' --query SecretString --output text)",
          "EXP_PW=$(aws secretsmanager get-secret-value --region ${var.region} --secret-id '${aws_secretsmanager_secret.db_exporter.name}' --query SecretString --output text)",
          "[ -z \"$DB_PW\" ] && { echo 'FATAL: DB password not loaded from Secrets Manager'; exit 1; }",

          "echo '=== 1. 하드웨어 볼륨 강제 인식 및 마운트 ==='",
          "TARGET_DEV=''",
          "for dev in /dev/nvme1n1 /dev/xvdf /dev/sdf;",
          "do if [ -b $dev ]; then TARGET_DEV=$dev; break; fi;",
          "done",
          "[ -z $TARGET_DEV ] && { echo 'Error: Storage device not found!'; exit 1; }",
          "if ! blkid $TARGET_DEV;",
          "then mkfs -t ext4 $TARGET_DEV; fi",
          "mkdir -p /mnt/production_db_data",
          "mountpoint -q /mnt/production_db_data || mount $TARGET_DEV /mnt/production_db_data",
          "if ! grep -q '/mnt/production_db_data' /etc/fstab;",
          "then echo \"$TARGET_DEV /mnt/production_db_data ext4 defaults,nofail 0 2\" >> /etc/fstab;",
          "fi",

          "echo '=== 2. private S3에서 DB SQL artifact 수거 ==='",
          "mkdir -p /mnt/production_db_data/app/scripts && cd /mnt/production_db_data/app",
          "aws s3 cp 's3://${var.db_artifacts_bucket_name}/${var.db_artifacts_prefix}/db_init.sql' scripts/db_init.sql",
          "aws s3 cp 's3://${var.db_artifacts_bucket_name}/${var.db_artifacts_prefix}/db_seed.sql' scripts/db_seed.sql || echo 'WARNING: db_seed.sql artifact not found'",
          "aws s3 cp 's3://${var.db_artifacts_bucket_name}/${var.db_artifacts_prefix}/db_reset.sql' scripts/db_reset.sql || echo 'WARNING: db_reset.sql artifact not found'",
          "[ -f scripts/db_init.sql ] || { echo 'FATAL: scripts/db_init.sql missing from S3 artifact'; exit 1; }",

          "echo '=== 2-1. private ECR 로그인 및 이미지 확인 ==='",
          "ECR_REGISTRY=$(printf '%s' '${var.mariadb_image_uri}' | cut -d/ -f1)",
          "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin \"$ECR_REGISTRY\"",
          "docker pull '${var.mariadb_image_uri}'",
          "docker pull '${var.node_exporter_image_uri}'",
          "docker pull '${var.mysqld_exporter_image_uri}'",

          "echo '=== 3. MariaDB 컨테이너 기동 ==='",
          "docker rm -f mariadb-server || true",
          "docker run -d --name mariadb-server --restart always -p 3306:3306 -e MARIADB_ROOT_PASSWORD=\"$DB_PW\" -e MARIADB_DATABASE='${var.db_name}' -e MARIADB_USER='${var.db_app_user}' -e MARIADB_PASSWORD=\"$DB_PW\" -v /mnt/production_db_data/mysql_data:/var/lib/mysql -v /mnt/production_db_data/app/scripts/db_init.sql:/docker-entrypoint-initdb.d/01_init.sql '${var.mariadb_image_uri}'",

          "echo '=== 4. 헬스체크 및 계정 주입 ==='",
          "for i in {1..30};",
          "do if docker exec mariadb-server mysql -u root -p\"$DB_PW\" -e 'SELECT 1' >/dev/null 2>&1; then DB_READY=1; break; fi; echo \"Waiting for MariaDB root auth... ($i/30)\"; sleep 3;",
          "done",
          "[ \"$${DB_READY:-0}\" = \"1\" ] || { echo 'FATAL: MariaDB root auth did not become ready'; docker logs --tail 120 mariadb-server || true; exit 1; }",
          "docker exec -i mariadb-server mysql -u root -p\"$DB_PW\" < scripts/db_init.sql",
          "docker exec -i mariadb-server mysql -u root -p\"$DB_PW\" -e \"CREATE USER IF NOT EXISTS '${var.db_exporter_user}'@'%' IDENTIFIED BY '$EXP_PW'; GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${var.db_exporter_user}'@'%'; FLUSH PRIVILEGES;\"",
          "docker exec -i mariadb-server mysql -u root -p\"$DB_PW\" -e \"GRANT SLAVE MONITOR ON *.* TO '${var.db_exporter_user}'@'%'; FLUSH PRIVILEGES;\" 2>/dev/null || echo 'INFO: SLAVE MONITOR grant skipped'",

          "echo '=== 4-1. 시드 데이터 주입 (db_seed.sql) ==='",
          "if [ -f scripts/db_seed.sql ]; then",
          "  docker exec -i mariadb-server mysql -u root -p\"$DB_PW\" '${var.db_name}' < scripts/db_seed.sql || echo 'WARNING: db_seed.sql execution failed; continuing DB deployment'",
          "else",
          "  echo 'db_seed.sql 파일이 존재하지 않아 시드 주입을 건너뜁니다.'",
          "fi",

         "echo '=== 4-2. 수동 Drop 명령어 스크립트 작성 ==='",
          "cat << 'DROP_SCRIPT' > /home/ssm-user/db_drop_execute.sh",
          "#!/bin/bash",
          "set -euo pipefail",
          "",
          "# AWS Secrets Manager에서 패스워드 추출",
          "DB_PW=$(aws secretsmanager get-secret-value --region ${var.region} --secret-id '${aws_secretsmanager_secret.db_app.name}' --query SecretString --output text)",
          "",
          "if [ -f /mnt/production_db_data/app/scripts/db_reset.sql ]; then",
          "  echo '수동 DB Drop 신호를 감지했습니다. 스크립트를 실행합니다...'",
          "  ",
          "  docker exec -i -e MYSQL_PWD=\"$DB_PW\" mariadb-server mysql -u root '${var.db_name}' < /mnt/production_db_data/app/scripts/db_reset.sql",
          "  ",
          "  echo 'DB Drop 완료되었습니다.'",
          "else",
          "  echo '에러: /mnt/production_db_data/app/scripts/db_reset.sql 파일이 존재하지 않습니다.'",
          "  exit 1",
          "fi",
          "DROP_SCRIPT",
          "chmod +x /home/ssm-user/db_drop_execute.sh",
          "echo '-> 이제 필요 시 EC2 내에서 [/home/ssm-user/db_drop_execute.sh] 실행 시 즉시 drop이 가능합니다.'",

          "echo '=== 5. 백업 자동화 구성 ==='",
          "mkdir -p /home/ssm-user/backups",
          "cat << 'SCRIPT' > /home/ssm-user/db_backup.sh",
          "#!/bin/bash",
          "set -euo pipefail",
          "DATE=$(date +%Y%m%d_%H%M%S)",
          "DB_PW=$(aws secretsmanager get-secret-value --region ${var.region} --secret-id '${aws_secretsmanager_secret.db_app.name}' --query SecretString --output text)",
          "docker exec -i mariadb-server mysqldump -u root -p\"$DB_PW\" ${var.db_name} > /home/ssm-user/backups/backup_$DATE.sql",
          "aws s3 cp /home/ssm-user/backups/backup_$DATE.sql s3://${var.db_backup_bucket_name}/",
          "find /home/ssm-user/backups -type f -name '*.sql' -mtime +7 -delete",
          "SCRIPT",
          "chmod +x /home/ssm-user/db_backup.sh && (crontab -l 2>/dev/null | grep -v 'db_backup.sh' || true; echo '0 3 * * * /home/ssm-user/db_backup.sh') | crontab -",

          "echo '=== 6. node_exporter 설치 ==='",
          "docker rm -f node-exporter 2>/dev/null || true",
          "docker run -d --name node-exporter --restart always --net=host --pid=host -v /:/host:ro,rslave '${var.node_exporter_image_uri}' --path.rootfs=/host --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/.+)($$|/)'",
          "for i in $(seq 1 20); do if curl -sf http://localhost:9100/metrics | grep -q 'node_filesystem_avail_bytes'; then echo 'node_exporter: OK'; break; fi; if [ $i -eq 20 ]; then echo 'WARN: node_exporter timeout'; fi; sleep 3; done",

          "echo '=== 7. mysqld_exporter 설치 ==='",
          "docker rm -f mysqld-exporter 2>/dev/null || true",
          "mkdir -p /mnt/production_db_data/exporter",
          "cat > /mnt/production_db_data/exporter/.my.cnf <<MYSQLD_EXPORTER_CNF",
          "[client]",
          "user=${var.db_exporter_user}",
          "password=$EXP_PW",
          "host=127.0.0.1",
          "port=3306",
          "MYSQLD_EXPORTER_CNF",
          "chmod 600 /mnt/production_db_data/exporter/.my.cnf",
          "docker run -d --name mysqld-exporter --restart always --net=host --user 0:0 -v /mnt/production_db_data/exporter/.my.cnf:/cfg/.my.cnf:ro '${var.mysqld_exporter_image_uri}' --config.my-cnf=/cfg/.my.cnf",
          "for i in $(seq 1 20); do if curl -sf http://localhost:9104/metrics | grep -q '^mysql_up 1'; then echo 'mysqld_exporter: OK'; break; fi; if [ $i -eq 20 ]; then echo 'WARN: mysqld_exporter timeout or DB connection failed'; fi; sleep 3; done",

          "echo '=== 8. 통합 검증 (스키마 정합성) ==='",
          "EXPECTED_TABLES=5",
          "ACTUAL_TABLES=$(docker exec mariadb-server mysql -u root -p\"$DB_PW\" -N -e \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${var.db_name}';\" 2>/dev/null || echo 0)",
          "if [ \"$ACTUAL_TABLES\" -lt \"$EXPECTED_TABLES\" ]; then echo \"FATAL: schema validation failed. Expected $EXPECTED_TABLES tables, got $ACTUAL_TABLES.\"; docker exec mariadb-server mysql -u root -p\"$DB_PW\" -e \"SHOW TABLES;\" '${var.db_name}' || true; exit 1; fi",
          "echo \"Schema validation passed: $ACTUAL_TABLES tables.\"",
          "curl -sf http://localhost:9100/metrics > /dev/null && echo 'node_exporter check: OK' || echo 'node_exporter check: FAIL'",
          "curl -sf http://localhost:9104/metrics | grep -q '^mysql_up 1' && echo 'mysqld_exporter check: OK' || echo 'mysqld_exporter check: FAIL'",

          "echo '=== MariaDB deploy script completed ==='"
        ]
      }
    }
  ]
}
EOF
}

# 8. MariaDB 기동 명령 실행 + 완료 검증 (C5 수정: fire-and-forget 제거)
resource "null_resource" "execute_ssm_command" {
  depends_on = [null_resource.wait_for_user_data]

  # M6: 문서 내용이나 인스턴스가 바뀌면 재실행한다.
  triggers = {
    instance_id  = aws_instance.db.id
    document_sha = sha1(aws_ssm_document.run_mariadb.content)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<BAR
      set -e
      CMD_ID=$(aws ssm send-command \
        --instance-ids "${aws_instance.db.id}" \
        --document-name "${aws_ssm_document.run_mariadb.name}" \
        --comment "MariaDB deploy" \
        --query "Command.CommandId" --output text)
      echo "=== SSM command sent: $CMD_ID. Waiting for completion... ==="

      for i in $(seq 1 180); do
        STATUS=$(aws ssm get-command-invocation \
          --command-id "$CMD_ID" \
          --instance-id "${aws_instance.db.id}" \
          --query "Status" --output text 2>/dev/null || echo "Pending")

        case "$STATUS" in
          Success)
            echo "=== MariaDB deploy verified successfully ==="
            exit 0
            ;;
          Failed|Cancelled|TimedOut)
            echo "=== MariaDB deploy FAILED. Dumping command output ==="
            aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "${aws_instance.db.id}" \
              --query "StandardErrorContent" --output text || true
            exit 1
            ;;
        esac

        sleep 5
      done

      echo "=== MariaDB deploy TIMEOUT. Dumping command output ==="
      aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "${aws_instance.db.id}" \
        --query "StandardErrorContent" --output text || true
      exit 1
BAR
  }
}
