# 使用官方 Node.js 18 alpine 镜像作为基础
FROM node:18-alpine

# 在容器内设置工作目录
WORKDIR /usr/src/app

# 复制 package.json 和 package-lock.json (如果存在)
# 这样可以利用 Docker 的层缓存机制，只有在依赖更新时才重新安装
COPY package*.json ./

# 安装项目依赖
RUN npm install

# 将项目的所有文件复制到工作目录
COPY . .

# 暴露端口（Koyeb 会自动注入 PORT 环境变量）
EXPOSE 8000

# CMD 指令定义了容器启动时要运行的命令
CMD [ "npm", "start" ]
