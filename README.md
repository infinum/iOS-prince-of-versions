Prince of versions
=================
![Platform](https://img.shields.io/badge/pod-1.0.0-blue.svg)
![License](https://img.shields.io/cocoapods/l/SemanticVersioning.svg)

Library checks for updates using configuration from some resource.

Features
--------
  * Load update configuration from **network** resource
  * Use predefined parser for parsing update configuration in **JSON format**
  * Make **asynchronous** loading and use **callback** for notifying result
  * Loading and verifying versions happen **outside of UI thread**

----------
### Install

### JSON file

If you are using a default parser, version in your application and the JSON file has to follow [Semantic Versioning](http://semver.org/).JSON file has to look like this:

```json
{
	"ios": {
		"minimum_version": "1.2.3",
		"optional_update": {
			"version": "2.4.5",
			"notification_type": "ALWAYS"
		}
	},
	"android": {
		"minimum_version": "1.2.3",
		"optional_update": {
			"version": "2.4.5",
			"notification_type": "ONCE"
		}
	},
	"meta": {
		"key1": "value1",
		"key2": "value2"
	}
}
```

Depending on <code>notification_type</code> property, the user can be notified <code>ONCE</code> or <code>ALWAYS</code>. The library handles this for you, and if notification type is set to <code>ONCE</code>, it will notify you via <code>newUpdate(version: String, isMandatory: boolean, metadata: [String: AnyObject]?)</code> method only once. Every other time the library will return <code>noUpdate</code> for that specific version. 
Key-value pairs under <code>"meta"</code> key are optional metadata of which any amount can be sent accompanying the required fields.


Usage
-------------
Full example application is available [here](ExampleApp).


### Contributing

Feedback and code contributions are very much welcome. Just make a pull request with a short description of your changes. By making contributions to this project you give permission for your code to be used under the same [license](https://github.com/infinum/Android-prince-of-versions/blob/dev/LICENCE).
