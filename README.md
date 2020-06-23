# syncable-minecraft
Run your Minecraft server anywhere there is Docker available, powered by your cloud file hosting provider of choice and rclone!

## Example run (Dropbox as provider):
```docker run -it -P --rm -e "REMOTE_RCLONE_AUTH={\"access_token\":\"super-secret-dropbox-token-here\",\"token_type\":\"bearer\",\"expiry\":\"0001-01-01T00:00:00Z\"}" -e "REMOTE_TYPE=dropbox" -e "REMOTE_FOLDER=cloud/drive/sub/folder/here" -e "STARTUP=java -jar optional-custom-jar-for-custom-start-args.jar" jasoryeh/syncable-minecraft```

## Container configuration
### Environment variables

### Required
`REMOTE_TYPE` = The RCLONE supported provider for file storage, this must be the same as the provider you used for the authorization below
`REMOTE_RCLONE_AUTH` = The string RCLONE returns you after authorizing locally via your provider of choice using `rclone authorize "$REMOTE_TYPE"`
`REMOTE_FOLDER` = Path to folder used on file storage provider

#### Optional
`STARTUP` = Startup arguments if different from `java -jar server.jar`
`REMOTE_NGROK_TOKEN` = If you wish to use NGROK TCP tunneling to access this Minecraft server, please specify the token, and it will be used. Other wise default networking will be used.
`REMOTE_PORT` = For ngrok mostly, specify this if your server.properties is anything other than 25565

### Notes
Default ports exposed are 53682 and 25565 (with -P ?), specify more with `-p (host):(container)`