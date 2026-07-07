FROM node:22-alpine

RUN npm install -g npm@11.18.0 && npm cache clean --force

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

USER node

EXPOSE 3004

CMD ["node", "main.js"]
