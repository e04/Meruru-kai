# Meruru-kai 

Meruruのフォークです。

https://github.com/castaneai/Meruru


- チャンネルリストからワンセグを除外するように変更
- チャンネル切り替えをメニューバーからするように変更
- URLスキームで開けるように変更。（EPGStation用）
  - EPGStation2.0以降で、設定からURLスキームに`meruru://ADDRESS`と入れれば、ブラウザから開けます。
  
- 表示がおかしいバグなどを修正

## Config

The Meruru config file is placed in `~/.config/meruru/config.json`.
Put the Mirakurun HTTP endpoint in `"mirakurunPath"` as follows:

```json
{
  "mirakurunPath": "http://192.168.x.x:40772"
}
```

## Build

- Install [Carthage](https://github.com/Carthage/Carthage)
- Run `carthage install`

## License

[Apache License, Version 2.0](LICENSE)
