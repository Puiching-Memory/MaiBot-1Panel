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

1panel提供的Docker镜像在拉取napcat镜像时会出现问题，建议添加更多镜像源，参考：https://status.anye.xyz/

> [!WARNING]  
> 本应用不内置 NapCat，请单独部署 NapCat，并在 `./docker-config/adapters/config.toml` 中配置对应的连接地址。
> 你也可以使用我们的NapCat APP集成，位于https://github.com/Puiching-Memory/MaiBot-1Panel/tree/napcat
> 目前尚未提供napcat的自动安装脚本，但是安装逻辑是相同的

> [!WARNING]
> 本应用不内置数据库可视化工具（如 Chat2DB / SQLite-Web），如需使用请在 1Panel 中单独安装对应应用，或自行以 Docker 方式部署，并连接到 `./data/MaiBot/MaiBot.db`。

> [!NOTE]
> 相关项目： https://github.com/Fahaxikiii/napcat-1panel
> 该第三方项目允许将 NapCat 部署为独立 1Panel 应用。它默认连接到`Host network`。

#### NapCat 配置说明：
1. 打开`应用日志`，找到NapCat WebUI 临时token
2. 打开web UI，使用临时token登录
3. 在`网络配置`中，添加新的webSocket客户端，地址填写 `ws://maibot_adapters:8095`（或你在 `config.toml` 中配置的地址）
4. (可选)，添加新的http服务器，地址填写 0.0.0.0:<端口号>

#### MaiBot 配置说明：
1. MaiBot WebUI 默认端口 18001，访问地址：http://您的服务器IP:18001
2. 在"麦麦适配器设置"页面，修改工作模式为"预设模式"，然后选择"部署方式"为Docker
3. 在相同页面点击"聊天控制"选项，添加群聊黑白名单
4. 在1Panel的"应用商店"页面重启"maibot"，更新适配器设置

> [!WARNING]
> 使用 WebUI 保存适配器配置之后，WebUI 的重启功能并不会重启适配器，必须在 1Panel 重启整个应用。

## 安装插件

插件路径位于：
```bash
/opt/1panel/apps/local/maibot/localmaibot/data/MaiMBot/plugins
```

## Docker DNS 解析

所有容器均加入 `1panel-network`，因此可以通过服务名直接解析并互通：
- `maibot_adapters` → MaiBot 适配器容器
- `maibot` → MaiBot 核心容器

## 代办事项

- [ ] 1Panel 目前不接受小于1w星的应用上架

## EULA
- 安装默认同意MaiBot EULA（不确定该策略是否合理，请在issue中反馈）

## 兼容性矩阵
| MaiBot版本 |    Adapters版本    | NapCat版本 |
| :--------: | :----------------: | :--------: |
|   0.12.0   | dev-20251220054512 |   4.9.83   |
|   0.12.1   | dev-20251227133620 |   4.9.98   |
|   0.12.2   | dev-20260116153739 |  4.10.41   |

## 参考

- https://github.com/1Panel-dev/appstore/wiki/%E5%A6%82%E4%BD%95%E6%8F%90%E4%BA%A4%E8%87%AA%E5%B7%B1%E6%83%B3%E8%A6%81%E7%9A%84%E5%BA%94%E7%94%A8
- https://docs.mai-mai.org/manual/deployment/mmc_deploy_docker.html
- https://docs.mai-mai.org/