# CineFlow 信令服务器部署指南

## 🌐 国内可直连免费托管平台清单

### 1. **Zeabur** ⭐⭐⭐⭐⭐ (最推荐)
- **优势**: 中国团队开发，国内访问速度快
- **免费额度**: 按使用量计费，有免费额度
- **部署方式**: 
  1. 访问 [zeabur.com](https://zeabur.com)
  2. 连接GitHub仓库
  3. 选择 `cineflow-signaling-server` 目录
  4. 自动部署
- **配置文件**: `zeabur.json`

### 2. **Vercel** ⭐⭐⭐⭐
- **免费额度**: 100GB流量/月，无需信用卡
- **部署方式**:
  1. 访问 [vercel.com](https://vercel.com)
  2. Import Git Repository
  3. 设置Root Directory为 `cineflow-signaling-server`
  4. 部署
- **配置文件**: `vercel.json`

### 3. **Netlify** ⭐⭐⭐⭐
- **免费额度**: 100GB流量/月，300分钟构建时间
- **部署方式**:
  1. 访问 [netlify.com](https://netlify.com)
  2. New site from Git
  3. 选择仓库和分支
  4. 设置Base directory为 `cineflow-signaling-server`
- **配置文件**: `netlify.toml`
- **注意**: 需要创建serverless函数适配

### 4. **Glitch** ⭐⭐⭐
- **免费额度**: 无明确限制
- **部署方式**:
  1. 访问 [glitch.com](https://glitch.com)
  2. New Project → Import from GitHub
  3. 选择仓库，会自动识别Node.js项目
- **配置文件**: `glitch.json`

### 5. **Railway** ⭐⭐⭐ (需要信用卡)
- **免费额度**: 500小时/月
- **部署方式**: GitHub集成
- **配置文件**: `railway.toml`

### 6. **Render** ⭐⭐ (需要信用卡)
- **免费额度**: 750小时/月
- **部署方式**: GitHub集成
- **配置文件**: `render.yaml`

## 🐳 Docker部署 (通用方案)

所有支持Docker的平台都可以使用：

```bash
# 构建镜像
docker build -t cineflow-signaling-server .

# 运行容器
docker run -p 8000:8000 -e NODE_ENV=production cineflow-signaling-server
```

## 📋 部署前检查清单

- [ ] 确保 `package.json` 包含正确的启动脚本
- [ ] 确保 `server.js` 使用环境变量 `PORT`
- [ ] 测试本地运行: `npm install && npm start`
- [ ] 检查防火墙和CORS设置
- [ ] 准备环境变量: `NODE_ENV=production`

## 🚀 推荐部署顺序

1. **首选**: Zeabur (国内速度最快)
2. **备选**: Vercel (全球CDN)
3. **备选**: Netlify (稳定可靠)
4. **最后**: Glitch (简单易用)

## 🔧 部署后配置

部署成功后，将获得的URL更新到Flutter应用中：

```dart
// lib/network/signaling_client.dart
static const String defaultServerUrl = 'https://your-deployed-url.com';
```

## 📞 技术支持

如遇到部署问题，请检查：
1. 构建日志中的错误信息
2. 环境变量配置
3. 端口设置 (默认8000)
4. Node.js版本兼容性 (推荐18.x)
