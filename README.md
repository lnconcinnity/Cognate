# Cognate
An advanced, powerful, roblox executor simulator!

With Cognate, you don't have to fret about downloading malicious executors situated on the internet, where, who knows? Be at risk to get banned or have your system inevitably be infested with viruses.

Thanks to this framework, you are free to simulate a near-identical commercial executor hosted on roblox, and because of it's flexible typing and naming, you can thereafter dissolve the needs to use special Cognate methods and Cognate sources once you're done code-pen'ing!

Scripts that interacts with Cognate are categorized in two states: `static` and `env`; a script can be either a `static` or `env` type with no inbetween and both are mutually exclusive to each other.

`env` scripts are scripts that truthfully simulates exploits, all simulated exploit methods are only found in these scripts as a global whereas `static` scripts are scripts that are pretty much normal, albeit can use static Cognate methods to reflect special variables. (See the static Cognate methods below.)

A script can be flagged as `env` by simply calling Cognate, e.g. `require(path.to.Cognate)()` at the top-most line of the script. Calling static Cognate methods as an `env` script will raise an error.

### Cognate Methods
- **`Cognate()`**
Any scripts initialized by calling the module itself will be flagged as an `env` script. These scripts will automatically have exploit-like functions such as `hookmethod`, `hookmetamethod`, `iscclosure`, and the likes, including Cognate Libraries, as globals.
- **`Cognate.Value(value: any) -> (CognateValue)`** Allows the emulation of variables, that way `getupvalues` and `setupvalue` can be mimicked. This method is a dynamic Cognate method and is not subjected to the exclusive restriction that `static` and `env` scripts hold.

##### Static Cognate Methods
- **`Cognate.Function(closure: (...any) -> (...any))`**
Allows the target function to be manipulated with `hookfunction`
- **`Cognate.Table(data: table)`**
Allows the target table to be in scope by `env`'s `getreg` method
- **`Cognate.Metatable()`**
Creates a dummy proxy and metatble in a way for it the be affected by `env`'s `getrawmetatable`, `setrawmetatable`, `setreadonly`, `isreadonly`, and `hookmetatable`.
- **`Cognate.Instance(className: string) -> (CognateInstance)`** A wrapper function for `Instance.new`; calling `CognateInstance:Destroy()` would only disconnect any bound events while setting it's parent to `nil`, children-wise, it'll also do the same as well, unless, such privilege would be ignored if an instance is not created via this method. Allows `env` scripts to retrieve `CognateInstances` via `getnilinstances` and as well other methods such as `cloneref`, `setparentinternal`, `addchildinternal` and `setpropertyinternal`. A special case wherein the instantiated object is either a `RemoteEvent`, `UnreliableRemoteEvent`, or `RemoteFunction`, they will be specially bound to an internal of `hookmetamethod`.
- **`Cognate.ReflectInstance(realInstance: Instance) -> (CognateInstance)`** Similar to `Cognate.Instance` but instead registers an already-instantiated object as a `CognateInstance`, best utilized when trying to simulate remote-based exploits 

# Game Structure
- DataModel
    - CoreServices (Workspace, Lighting, ReplicatedStorage, etc...)
    - nil_instances
    - cognate_sources
    - cognate_hui

# Notes from the developer
`cognate_sources` is a user-defined folder where the user can place `ModulesScripts` that shall act as `env` scripts. By simply using `require` on any source scripts (scripts that are located under `StarterGui`, `StarterPack`, `StarterCharacterScripts`, or `StarterPlayerScripts`) would make Cognate automatically search for this folder and run all modules in a sequence. The `nil_instances` folder is generated upon loading the game. `cognate_hui` is also a folder generated upon loading the game, this folder only contains `ObjectValues` where its `.Value` property redirects toward a `GuiObject` located under `Player.PlayerGui`.

The practice of using `Cognate.Value()` for your variables within your `env` scripts is accepted, however it is sadly discouraged as it *may* impact script performace on a miniscule scale.

Cognate is specifically designed to be a simulated client-sided executor. Any modifications done to the resource (such as allowing it to be server-sided) shall not held the developer, lnconcinnity alias RVCDev, accountable for any damages occured, such as Game Deletion and Account Moderation, hereafter the modification in detail is done.