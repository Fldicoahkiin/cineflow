# 使用官方 Node.js 18 alpine 镜像作为基础
FROM node:18-alpine

# 在容器内设置工作目录
WORKDIR /app

# 复制所有文件到工作目录
COPY . .

# 安装项目依赖
RUN npm install --production

# 暴露端口
EXPOSE 8000

# 启动应用
CMD ["npm", "start"]
