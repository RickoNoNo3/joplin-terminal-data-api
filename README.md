# Joplin-Terminal-Data-API
一个 docker image to 向外提供joplin客户端的Data API接口，包含了Joplin Terminal的全部功能以及一些便于无头(headless)环境使用的优化方案

## 前置介绍：Joplin Terminal
Joplin应用同时提供基于CLI的交互式界面、基于命令行参数的单命令执行器、以及Data API，这三者有如下区别：

- 交互式界面(by running `joplin`)：模仿了PC的GUI环境下Joplin的界面和使用体验，适合由用户直接在无GUI的环境下使用Joplin。
- 命令行参数(by running `joplin <command>`)：提供丰富的命令，可以直接以命令形式完成一些程序化的功能，不适合用户直接使用，只适合由管理员进行操作。可以直接shell中运行，也可以在交互式界面中去掉前缀`joplin`，改用`:<command>`格式运行。
- Data API(by calling `http://:41184`)：提供对笔记、笔记本、标签等等几个数据实体的RESTful CRUD服务。原本是Joplin Web Clipper插件专用的数据传输接口，但后续发现同时也适合进行各类基于Joplin数据的外围软件开发。不可更改Joplin配置，不适合用户直接使用。

# Joplin-Terminal-Data-API
A docker image to provide the Joplin's Data API externally, containing all features of Joplin Terminal as well as some optimization schemes suitable for headless use

## Introduction: Joplin Terminal
The Joplin application offers an interactive interface based on CLI, a single command executor based on command-line arguments, and a Data API. The differences among these are as follows:

- Interactive interface (by running `joplin`): Mimics the interface and user experience of Joplin under a GUI environment on PC, suitable for direct use by users in environments without GUI.
- Command-line arguments (by running `joplin <command>`): Provides a variety of commands that can execute some programmatic functionalities directly in the form of commands, not suitable for direct use by users, only suitable for operation by administrators. Can be run directly in the shell, or in the interactive interface by omitting the prefix `joplin` and using the `:<command>` format instead.
- Data API (by calling `http://:41184`): Offers RESTful CRUD services for several data entities such as notes, notebooks, tags, etc. Initially exclusive for data transfer with the Joplin Web Clipper plugin, but later found to also be suitable for the development of various peripheral software based on Joplin data. Cannot modify Joplin configurations, not suitable for direct use by users.


## Deployment
```
docker pull rickonono3/joplin-terminal-data-api:latest
```

只需映射一个端口(使用OneDrive同步可能需要两个端口)与一个配置文件：
| Port/Volumn              | Necessary | Description                 |
| ------------------------ | --------- | --------------------------- |
| 9967                     | ✗         | OneDrive OAuth Service      |
| 41184                    | ✗         | Joplin Data API             |
| 41185                    | ✓         | Joplin Data API (AutoToken) |
| /root/joplin-config.json | ✓         | Joplin Config File          |

> 我们使用Nginx反向代理对Data API请求进行进一步包装，主要自动完成query string中的token。这是因为在容器中以动态鉴权形式认证每一个调用Data API的程序来源实在相当不便，这种鉴权使得本容器仅作为Web API接口而不应有用户参与其中的定位发生了变化，从而丢失了其自动化的能力。因此对大部分确保信息安全的场景下，你都可以使用41185而非Joplin原本的41184端口，并且无需再担心鉴权及token的问题。

## Configuration
By using `joplin help config` in a container terminal，we can find all the configuration keys of joplin. And，we can get an example of the config file:

```json
{
  "dateFormat": "DD/MM/YYYY",
  "folders.sortOrder.field": "title",
  "layout.folderList.factor": 1,
  "layout.note.factor": 2,
  "layout.noteList.factor": 1,
  "locale": "en_GB",
  "net.proxyTimeout": 1,
  "notes.sortOrder.field": "user_updated_time",
  "notes.sortOrder.reverse": true,
  "revisionService.enabled": true,
  "revisionService.ttlDays": 90,
  "showCompletedTodos": true,
  "sync.8.url": "https://s3.amazonaws.com/",
  "sync.interval": 300,
  "sync.maxConcurrentConnections": 5,
  "sync.target": 5,
  "sync.wipeOutFailSafe": true,
  "timeFormat": "HH:mm",
  "trackLocation": true,
  "uncompletedTodosOnTop": true
}
```

由于每次重启容器都会使用`joplin config --import < /root/joplin-config.json`重新导入配置，在容器终端中使用命令`joplin config <key> <value>`将在下次重启容器时失效。需要持久保存的配置项请一律写入`joplin-config.json`。

## Data API

For API Request/Response formats, 请查看[Joplin官方文档](https://joplinapp.org/help/api/references/rest_api/#using-the-api)。

在Joplin原本的情况下，使用Data API需要首先获取Clipper Token。由于Joplin CLI不容易进行`auth`，这里直接使用一个固定的通用的token。已经通过Nginx反向代理自动填充了此token在每一个对Data API的请求中。因此你调用Data API的端口不是Joplin原始的41184端口，而是Nginx的41185。向41185发送的请求，无需手动给定token（区别于Joplin官方文档的写法）。*Use it at your own risk.*

如果你还是想详细了解获得token的方法，下面给出：

```
cat /root/.config/joplin/settings.json|grep 'token'|sed 's/^.*"\([^"]*\)".*$/\1/g'

# (example) the api token:
# f724edfab395...
```

## E2EE
`joplin e2ee`的用法由`joplin help e2ee`给出：

```txt
e2ee <command> [path]

    Manages E2EE configuration. Commands are `enable`, `disable`, `decrypt`, `status`, 
    `decrypt-file`, and `target-status`.

    -p, --password <password>  Use this password as master password (For security reasons, it is not 
                               recommended to use this option).
    -v, --verbose              More verbose output for the `target-status` command
    -o, --output <directory>   Output directory
    --retry-failed-items       Applies to `decrypt` command - retries decrypting items that 
                               previously could not be decrypted.
```

一般情况下，使用`joplin e2ee enable -p <password>`即可完成同步时自动编码解码


## Synchronization
除OneDrive外，其他同步源，都直接按如下方式配置：
1. 按照`joplin help config`里的介绍，将同步源配置在`joplin-config.json`中
2. 在容器中执行`joplin sync`，根据提示完成配置。

下面主要说一下OneDrive的同步方式。

由于OneDrive同步源需要首先从Microsoft登录，而Microsoft登录只有网页GUI版本，因此Joplin使用了一个临时供外部访问的服务器来完成登录认证，即端口9967上的service。然而，对于一个CLI环境，使用GUI网页浏览器是困难的，因此我在阅读Joplin CLI源码后，给出如下解决方案：

解决方案1：宿主机具备GUI，并且宿主机可映射9967端口

1. 映射9967端口到宿主机9967端口（必须恰好是9967端口，而且此端口仅在登录onedrive时使用一次，如果不想映射到此端口，请直接使用方法2）
2. 确保配置文件中"sync.target"为3，如果不是则配置后重启容器
3. 追加一个终端在容器中，执行`joplin sync`，显示需要访问<http://127.0.0.1:9967/auth>，在宿主机访问它，完成所有步骤后即可配置完成同步

解决方案2：宿主机不具备GUI，或不可映射9967端口
1. 确保配置文件中"sync.target"为3，如果不是则配置后重启容器
2. 追加一个终端在容器中，执行`joplin sync`，显示需要访问`http://127.0.0.1:9967/auth`，不要打开它（打开也无法访问）
3. 在任意一台具备GUI的电脑上访问如下URL：<https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=e09fc0de-c958-424f-83a2-e56a721d331b&scope=files.readwrite+offline_access+sites.readwrite.all&redirect_uri=http%3a%2f%2flocalhost%3a9967&response_type=code&prompt=login>. 这一步与[Joplin源代码](<https://github.com/laurent22/joplin/blob/d7a0d74c4da96cca27af07b3c908a7ca97227be7/packages/lib/onedrive-api.ts#L87>) 等价
4. 当验证完成最后一步后，将跳转到`http://localhost:9967/?code=<onedrive_auth_code>`，此时将提示无法显示界面。让我们再追加一个新终端在容器里（此时容器里有两个终端，一个是新追加的sh，另一个是joplin sync正在等待OneDrive登录），把浏览器地址栏中的地址复制，使用`wget <http://...url>`命令在容器中访问一次。
5. 查看运行`joplin sync`的那个终端，应该显示登录成功