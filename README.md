# 1Panel App Store - MaiBot 集成

## 安装

目的：将 MaiBot APP 文件夹放在 `/opt/1panel/resource/apps/local/` 下  
你可以使用我们提供的自动脚本，也可以选择手动安装  
执行脚本后，你可能需要手动点击1panel `应用商店` -> `全部` -> `同步本地应用`  

```bash
curl -fsSL -o install_MaiBot_1Panel.bash https://raw.githubusercontent.com/Puiching-Memory/MaiBot-1Panel/MaiBot/apps/maibot/install.bash
bash install_MaiBot_1Panel.bash install      # 全新安装
bash install_MaiBot_1Panel.bash update       # 更新到最新版本
bash install_MaiBot_1Panel.bash version      # 查看当前安装版本和脚本版本
bash install_MaiBot_1Panel.bash help         # 显示帮助信息
```

## 在1Panel面板中完成后续部署

本应用已内置 NapCat 服务，部署后会同时启动 MaiBot 核心与 NapCat QQ 连接器。若 1Panel 在拉取 NapCat 镜像时出现问题，建议添加更多镜像源，参考：https://status.anye.xyz/

> [!WARNING]
> 本应用不内置数据库可视化工具（如 Chat2DB / SQLite-Web），如需使用请在 1Panel 中单独安装对应应用，或自行以 Docker 方式部署，并连接到 `./data/MaiBot/MaiBot.db`。

> [!NOTE]
> 相关项目： https://github.com/Fahaxikiii/napcat-1panel (已停更)
> 该第三方项目允许将 NapCat 部署为独立 1Panel 应用。它默认连接到`Host network`。

#### 开始使用：
1. /opt/1panel/apps/local/maibot/maibot/docker-config/mmc/bot_config.toml 将webui监听地址改为0.0.0.0
2. MaiBot WebUI 默认端口 18001，访问地址：http://您的服务器IP:18001
3. Napcat WebUI 默认端口 6099，访问地址：http://您的服务器IP:6099，登录 QQ 并启用 WebSocket Server（端口 3001）
4. Napcat websocket Server host地址请填写：`ws://0.0.0.0:3001`, MaiBot ws host地址请填写：`ws://napcat:3001`
5. 登录token请在应用日志终端查看
6. 完成初始化配置

## 安装插件

插件路径位于：
```bash
/opt/1panel/apps/local/maibot/localmaibot/data/MaiMBot/plugins
```

## Docker DNS 解析

所有容器均加入 `1panel-network`，因此可以通过服务名直接解析并互通：
- `maibot` → MaiBot 核心容器
- `napcat` → NapCat QQ 连接器

## 代办事项

- [ ] 1Panel 目前不接受小于1w星的应用上架

## EULA
- 安装默认同意MaiBot EULA（不确定该策略是否合理，请在issue中反馈）

## 兼容性矩阵
| MaiBot版本 |        Adapters版本        | NapCat版本 |
| :--------: | :------------------------: | :--------: |
|   1.0.8    | 内置插件（NapCat Adapter） |  4.10.41+  |

## 参考

- https://github.com/1Panel-dev/appstore/wiki/%E5%A6%82%E4%BD%95%E6%8F%90%E4%BA%A4%E8%87%AA%E5%B7%B1%E6%83%B3%E8%A6%81%E7%9A%84%E5%BA%94%E7%94%A8
- https://docs.mai-mai.org/manual/deployment/mmc_deploy_docker.html
- https://docs.mai-mai.org/