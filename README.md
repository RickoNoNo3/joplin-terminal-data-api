# Joplin-Terminal-Data-API
A docker image to provide the Joplin's Data API externally, containing all features of Joplin Terminal as well as some optimization schemes suitable for headless use

## Introduction: Joplin Terminal
Joplin Terminal offers several interfaces: an interactive application based on CLI, a command executor based on command-line arguments, and a Data API. The differences among these are as follows:

- Interactive Application (by running `joplin`): Mimics the interface and user experience of Joplin Desktop on PC, suitable for direct use by users in environments without GUI.
- Command-line arguments (by running `joplin <command>`): Provides a variety of commands that can execute some programmatic functionalities directly, not suitable for direct use by users, only suitable for operation by administrators. Can be run directly in the shell, or in the interactive application by omitting the prefix `joplin` and using the `:<command>` format instead.
- Data API (by sending HTTP requests to `http://:41184`): Offers RESTful CRUD services for several data entities such as notes, notebooks, tags, etc. Initially exclusive for data transfer with the Joplin Web Clipper plugin, but later found to also be suitable for the development of various peripheral softwares based on Joplin's data. Cannot modify Joplin configurations, not suitable for direct use by users.

This docker image is mainly for the last interface, Data API. It self-contains a Joplin Terminal application, enables Data API queries from external, and expose configurations to the host.

## Deployment
For dynamically running the latest version of Joplin, use the following command:

```
docker pull rickonono3/joplin-terminal-data-api:latest
```

Everytime the container is started/restarted, the latest version of Joplin will be downloaded and installed if necessary. So this is suitable for online use. If you want to run a specific version of Joplin to keep static or for offline use, run the following command:

```
docker pull rickonono3/joplin-terminal-data-api:<version>
```

(note that not every static version is released, see the [Docker Hub](https://hub.docker.com/r/rickonono3/joplin-terminal-data-api) for details)

There are only one port(for synchronizing to OneDrive maybe two) and a config file folder necessary you need to map:
| Port/Volume  | Necessary | Description                          |
| ------------ | --------- | ------------------------------------ |
| 9967         | ✗         | OneDrive OAuth Service               |
| 41184        | ✗         | Joplin Data API                      |
| 41185        | ✓         | Joplin Data API (AutoToken)          |
| /root/joplin | ✓         | The folder stored the Joplin config file |

> A sample docker startup:
> ```sh
> docker run -d --name joplin-data-api -p 41185:41185 \
>            -v /path_host/joplin:/root/joplin \
>            --restart unless-stopped \
>            rickonono3/joplin-terminal-data-api:latest
> ```

## Configuration
Mount a host folder to container's `/root/joplin` folder, and create a config file named `joplin-config.json` inside. You can do this regardless of how much times the container has been started (0, 1, or any), but you must start or restart the container (`docker restart`) for the changes to take effect.

From [the doc](https://joplinapp.org/help/apps/terminal/) (or by executing command `joplin help config` in a container terminal)，we can find all the configuration keys of Joplin. Then we can get an example of the config file:

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

Since the container re-imports the configuration with `joplin config --import < /root/joplin/joplin-config.json` every time it restarts, using the command `joplin config <key> <value>` in the container terminal will become ineffective upon the next restart. Write all configurations need to be persistently saved into `joplin-config.json`.

## Data API
For API Request/Response formats, see [Joplin Data API Document](https://joplinapp.org/help/api/references/rest_api)。

In the original Joplin setup, using the Data API first requires obtaining a Clipper Token with the confirmation by the user from Joplin client. Since it is not easy to be performed with Joplin CLI, especially in Docker containers, here we use a universal token instead. This token has already been automatically filled in every request to the Data API through the Nginx reverse proxy. Therefore, **the port you use to call the Data API is not Joplin's original 41184 port, but Nginx's 41185**. For requests sent to 41185, there is no need to manually provide a token (unlike the field described in the Joplin documentations). *Use it at your own risk.*

If you really still want to understand in detail:

```
cat /root/.config/joplin/settings.json | grep 'token' | sed 's/^.*"\([^"]*\)".*$/\1/g'

# (Example) The printed universal API token which appended as query string by Nginx RevProxy:
# f724edfab395...
```

For untypical safety consideration, you may manually retrive the token from `/root/.config/joplin/settings.json` in the container, and expose Joplin's default port 41184 rather than our auto-token reverse proxy on 41185, then use the API in the official way with `token` query.

## E2EE
The usage of command `joplin e2ee` is introduced by command `joplin help e2ee`:

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

Generally, using `joplin e2ee enable -p <password>` can complete the automatic encoding and decoding during synchronization.


## Synchronization
For sync targets other than OneDrive, configure directly as follows:
1. Configure the sync target in `joplin-config.json` according to the help doc or the stdout of `joplin help config`
2. Execute `joplin sync` inside the container, and follow the prompts (if exist) to complete the configuration.
3. The synchronization interval seconds is set into `sync.interval` in `joplin-config.json`.
4. While the first synchronization is completed and there is at least one item in the database (not blank), the synchronization will be performed automatically every `sync.interval` seconds.

Below, we mainly discuss the synchronization for OneDrive.

Since the OneDrive sync target requires login from Microsoft, and the Microsoft login is only available in a web GUI, Joplin uses a temporary external server for login authentication, which is on port 9967. However, using a GUI web browser in a CLI environment is too hard. After reading the Joplin source code about the sync target, We offer the following solutions:

Solution 1: The host machine has a GUI, and the 9967 port can be mapped
1. Map port 9967 to 9967 (it must be exactly 9967, and the port is only used once during the login to OneDrive. If you do not want to map to this port, please use Solution 2)
2. Ensure that "sync.target" in the configuration file is `3` and password has been correctly configured, if not, configure it and restart the container
3. Attach a terminal (sh) into the container, execute `joplin sync`, it will show that you need to visit <http://127.0.0.1:9967/auth>, access it on the host machine, complete all steps to finish the synchronization configuration

Solution 2: The host machine does not have a GUI, or the 9967 port is not available
1. Ensure that "sync.target" in the configuration file is `3` and password has been correctly configured, if not, configure it and restart the container
2. Attach a terminal (sh) into the container, execute `joplin sync`, it will show that you need to visit `http://127.0.0.1:9967/auth`, do not follow it.
3. On any safe computer with a GUI, access the following URL: <https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=e09fc0de-c958-424f-83a2-e56a721d331b&scope=files.readwrite+offline_access+sites.readwrite.all&redirect_uri=http%3a%2f%2flocalhost%3a9967&response_type=code&prompt=login>. *This step is equivalent to a piece of [Joplin source code](<https://github.com/laurent22/joplin/blob/d7a0d74c4da96cca27af07b3c908a7ca97227be7/packages/lib/onedrive-api.ts#L87>)*
4. After completing the last step in the browser, you will be redirected to `http://localhost:9967/?code=<onedrive_auth_code>`(^1). At this point, it will be 404 not found. Let's attach a new terminal in the container (now there are two terminals in the container, one is the newly added `sh`, the other is `joplin sync` waiting for OneDrive login). Copy the whole address(^1) from the browser, execute `wget "<your address>"` in the container to access it once.
5. Check the terminal running `joplin sync`, it should show that login was successful.

## Testing
After syncing, you may download the `content_view.html` file from this repository, and visit it in a browser (using file or http protocols) in a location which can connect to the Data API, to test the connection and view the tree structure of the notes.

