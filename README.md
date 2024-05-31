# syncable-minecraft
Run your Minecraft server anywhere there is Docker available, powered by your cloud file hosting provider of choice and rclone!

## Example run (Dropbox as provider):
```docker run -it -P --rm -e "STORAGE_AUTH={\"access_token\":\"super-secret-dropbox-token-here\",\"token_type\":\"bearer\",\"expiry\":\"0001-01-01T00:00:00Z\"}" -e "STORAGE_TYPE=dropbox" -e "STORAGE_FOLDER=cloud/drive/sub/folder/here" -e "STARTUP=java -jar optional-custom-jar-for-custom-start-args.jar" jasoryeh/syncable-minecraft```

## Container configuration
### Pre-setup
On the storage provider you choose to use:
- Ensure the folder the server is running off of (by default /syncmc) exists
- Upload the jar file you wish to use (by default server.jar)
- `rclone authorize "$STORAGE_TYPE"` on your local machine, make note of the JSON response (this will be used in STORAGE_AUTH)

### Environment variables

### Required
`STORAGE_TYPE` = Rclone's remote type (see a list of raw strings [here](https://github.com/rclone/rclone/blob/cd69f9e6e81c4bfab19b3c01cf1b0f221c6d7188/fstest/test_all/config.yaml#L13) and actual list with features [here](https://rclone.org/overview/))

`STORAGE_AUTH` = After authorizing locally with `rclone authorize "$STORAGE_TYPE"`, this is the authorization token you get.

`STORAGE_FOLDER` = Path to folder used on file storage provider ex. /coolfolderforserver/orsubpaths/to/server

#### Optional
`STARTUP` = Startup arguments if different from `java -jar server.jar`, syncable-minecraft uses OpenJDK 8 by default.

`AUTOSAVE` = Defaults to 300, specifies delay between autosaves (save-all) command in the server. A sync to the storage provider will usually be performed `AUTOSAVE` seconds after this save-all to ensure the world is properly saved.

`LOCK_OVERRIDE` = This container tries to make your server have a predictable state by using a SYNCABLE_LOCK file to show that the server is currently in use. Sometimes (such as when a server goes down unexpectedly), this doesn't get deleted and you may need to use this lock override to tell the container it is safe to proceed. It can be any value as long as it exists.

`SIMULTANEOUS_CMD` = A command to run in the background, maybe for your own SSH tunnel?

### Notes
Default port exposed is 25565 (with -P ?), specify more with `-p (host):(container)` or if your server wants to use a different port.
