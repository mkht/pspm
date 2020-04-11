# pspm - PowerShell Package Manager

pspm is the management tools for PowerShell modules.  
You can manage PowerShell modules [npm](https://www.npmjs.com/) like commands.


----
## Requirements

+ Windows PowerShell 5.0 or higher
+ PowerShell Core 6.0 or higher
+ Windows or macOS

> Testing platforms:  
> Windows 10 Pro x64 1809 with PowerShell 5.1 & PowerShell Core 6.1.1  
> macOS 10.14 Mojave with PowerShell Core 6.1.1

----
## Installation

You can install pspm from [PowerShell Gallery](https://www.powershellgallery.com/packages/pspm/).
```Powershell
Install-Module -Name pspm
```

#### Option: Update PowerShellGet
We strongly recommend using the latest PowerShellGet module to improve compatibility and stability.  
To update PowerShellGet use the following command and restart PowerShell.  

```PowerShell
Install-Module PowerShellGet -Force -AllowClobber
```

----
## Usage

### Install & Import Modules

The command `pspm install` will download a module from [PSGallery](https://www.powershellgallery.com/).  

```PowerShell
pspm install '<Module Name>'
```

This will create the `Modules` folder in the current directory and will download the module to that folder, then import it to the current PS session.

#### Tips: Specify the Module version

If you want to install specific version of the Module.  
You can specify the Module name with version or [semver](https://docs.npmjs.com/misc/semver#ranges) range syntax.  

```PowerShell
pspm install '<Module Name>@<Version>'  # e.g) pspm install 'Pester@4.1.0'
```

#### Tips: Specify the repository

If you want to install the module from specific repository (like Private repository)  
You can specify the PSRepository name.  
(You should register repositories before. See [Microsoft docs](https://docs.microsoft.com/en-us/powershell/module/powershellget/register-psrepository?view=powershell-7))

```PowerShell
pspm install '@<Repository Name>/<Module Name>'  # e.g) pspm install '@PrivateRepo/MyModule'
```


#### Tips: Get modules from GitHub :octocat:

You can download modules from GitHub repos.  
Just `<user>/<repo-name>` or `<user>/<repo-name>#<ref>`.  
`<ref>` as `branch` or `commit-hash` or `Tag`  

```PowerShell
pspm install '<user>/<repo-name>'
pspm install '<user>/<repo-name>#<ref>'
# e.g) pspm install 'pester/Pester#7aa9e63'
```

You can specify `Credential` or `GitHubToken` If you want to get modules from **private** repos.  
Also, if an environment variable `GITHUB_TOKEN` is present, pspm uses it as GitHub Personal Access Token.  
(Priority: `Credential` > `GitHubToken` > `GITHUB_TOKEN`)

```PowerShell
# Authenticate with Credential (username & password)
pspm install '<user>/<private-repo-name>' -Credential (Get-Credential)

# Authenticate with Personal Access Token
# You should convert token to [SecureString]
$SecureToken = ConvertTo-SecureString '<plain-token>' -AsPlainText -Force
pspm install '<user>/<private-repo-name>' -GitHubToken $SecureToken
```


#### Tips: Install multiple Modules at once

If you want to install multiple modules at once or manage modules as code.  
You can create `package.json` and run the `pspm install` without module name.  

If there is a `package.json` file in the working directory, pspm installs all modules in the list.  

About `package.json`, please refer [the section](#packagejson) below.


#### Option: Global installation

Install a module as global.  
Module will save to the `$env:ProgramFiles\WindowsPowerShell\Modules` (on Windows)

```PowerShell
pspm install '<Module Name>' -Global
pspm install '<Module Name>' -g
pspm install '<Module Name>' -Scope Global
```

#### Option: User installation

Install a module to current user profile.  
Module will save to the `$env:UserProfile\WindowsPowerShell\Modules` (on Windows)

```PowerShell
pspm install '<Module Name>' -Scope CurrentUser
```


#### Option: Clean installation

When `-Clean` switch specified, pspm will remove **ALL modules** in the `Modules` folder before install process.  

```PowerShell
pspm install '<Module Name>' -Clean
# WARNING: -Clean option will remove all modules in the Modules folder, NOT just the specified.
```


#### Option: Disable modules import

`pspm install` will import modules automatically after install.  
If you don't like this behavior, Specify `-NoImport` switch. 

```PowerShell
pspm install '<Module Name>' -NoImport
```

----
### Update Modules

The command `pspm update` will update modules.  

```PowerShell
pspm update '<Module Name>'   # specify the name of module
pspm update  # with package.json
```

**NOTICE:** The `pspm update` will change `package.json` to save the new version as the minimum required dependency. If you don't wanna update, use `pspm update -Save:$false`


#### Tips: What's the difference between install and update ?

Thought as below scenarios.  
+ The module `Example@1.0.0` is installed in the system.  
+ Latest version of `Example` is `1.2.0`.

In this scenario. If you run the command `pspm install 'Example@1.x'`, pspm will NOT update the module that because `1.0.0` is satisfied `1.x`.  
But if you run `pspm update 'Example@1.x'`, pspm will update the `Example` to `1.2.0`.  


----
### Uninstall Modules

To remove a module from your `Modules` folder, use:

```PowerShell
pspm uninstall '<Module Name>'
```

----
### Run scripts

pspm supports the `"scripts"` property of the `package.json`.  

```PowerShell
pspm run '<Script Name>'
pspm run '<Script Name>' -Arguments [Object[]]  #with arguments
pspm run '<Script Name>' -IfPresent  #run only when the scripts exist
#aliases: pspm run-script
```


### Special terms

You can omit `run` when running a script with some special words. (`start`, `restart`, `stop`, `test`)

```PowerShell
pspm start    # = pspm run start
pspm restart  # = pspm run restart
pspm stop     # = pspm run stop
pspm test     # = pspm run test
```


#### Example

Save `package.json` that has `scripts` property like below in the working directory.  

```json
"scripts": {"hello": "echo 'Hello pspm !'"}
```

To run `Hello` script, exec the command.

```PowerShell
PS> pspm run 'hello'
Hello pspm !
```


#### Tips: Use Arguments

You can use custom arguments when executing scripts.

```json
"scripts": {"name": "echo 'Your name is $args[0]'"}
```
```PowerShell
PS> pspm run 'name' -Arguments 'MyName'
Your name is MyName
```


#### Tips: Use "config" object

The `package.json` that has "config" keys. You can use the object as environment variable of `pspm_package_config_<key>`

```json
"scripts": {"show_port": "echo \"Port: $env:pspm_package_config_port\""},
"config" : {"port": "8080"}
```
```PowerShell
PS> pspm run 'show_port'
Port: 8080
```


#### Tips: Invoke script file

You can invoke outer PowerShell script file.

```json
"scripts": {"ps1": ".\\script.ps1"},
```


----
### Hook scripts

If you want to run a specific script at a specific timing, then you can use a hook script.

+ **install** hook
  - **preinstall**: Run BEFORE `pspm install`
  - **install**, **postinstall**: Run AFTER `pspm install`

+ **update** hook
  - **preupdate**: Run BEFORE `pspm update`
  - **update**, **postupdate**: Run AFTER `pspm update`

+ **uninstall** hook
  - **preuninstall**, **uninstall**: Run BEFORE `pspm uninstall`
  - **postuninstall**: Run AFTER `pspm uninstall`

+ Specific script hook
  - **prestart**, **poststart**: Run by the `pspm start`
  - **prerestart**, **postrestart**: Run by the `pspm restart`
  - **prestop**, **poststop**: Run by the `pspm stop`
  - **pretest**, **posttest**: Run by the `pspm test`

+ User-defined script hook
  - **pre\<name\>**, **post\<name\>**: Run by the `pspm run <name>`


#### Example

```json
"scripts": {
  "preinstall": "echo '(preinstall) run before install'",
  "install": "echo '(install) run after install'",
  "postinstall": "echo '(postinstall) run after install'"
  }
```

```PowerShell
PS> pspm install 'Pester@4.2.0'
(preinstall) run before install
Pester@4.2.0: Downloading module.
Pester@4.2.0: Importing module.
(install) run after install
(postinstall) run after install
```

----
## package.json

A package.json file:

+ lists the modules that your project depends on.
+ allows you to specify the versions of a module that you want to use.
+ define scripts for CI/CD process.


### scripts

You can define script in package.json  
Please refer [run scripts](#run-scripts)  

```json
"scripts": {"hello": "echo 'Hello pspm !'"}
```

### config

define environment variable for run-scripts.  
Please refer [run scripts](#run-scripts) 

```json
"config": {"port": "8080"}
```

### dependencies

To specify the modules your project depends on, you need to list the modules you'd like to use in your package.json file.  

```javascript
  "dependencies": {
    "<Module name 1>": "<Version>",
    "<Module name 2>": "<Version>"
  }
```

#### Specifying Module Versions

You can use [npm-semver](https://docs.npmjs.com/misc/semver#ranges) syntax for specifying versions.  

+ **Exact**
  - *version* Must match version exactly.  `"1.2.0"`
  - A leading `"="` or `"v"` is ignored.  `"v1.2.3" == "1.2.3"`

+ **Any**
  - `"*"` (asterisk) or `""` (empty) Any versions accepted.

+ **Latest**
  - `"latest"` Match only newest version

+ **Comparators**
  - *<*, *>*, *<=*, *>=* Less than, Greater than, Less equal, Greater equal `>=1.0.0`

+ **Hyphen Ranges**
  - *X.Y.Z - A.B.C* specifies an inclusive set.  `1.2.3 - 2.3.4 := >=1.2.3 <=2.3.4`

+ **X-Ranges**
  - `1.x := >=1.0.0 <2.0.0`
  - A partial version range is treated as an X-Range  `2.3 := 2.3.x := >=2.3.0 <2.4.0`

+ **Caret Ranges**
  - Allows changes that do not modify the left-most non-zero digit.
  - `^1.2.3 := >=1.2.3 <2.0.0`
  - `^0.0.3 := >=0.0.3 <0.0.4`

+ **Tilde Ranges**
  - `~1.2.3 := >=1.2.3 <1.3.0`
  - The rule of tilde range is bit complicated. Please refer [npm-docs](https://docs.npmjs.com/misc/semver#tilde-ranges-123-12-1).


### Example

This is valid `package.json` sample.
```json
{
  "scripts": {
    "hello": "echo 'hello pspm'",
    "show_port": "echo \"Port: $env:pspm_package_config_port\""
  },
  "config": {"port": "8080"},
  "dependencies": {
    "Pester": "4.x",
    "AWSPowerShell": "3.3.283.0",
    "PSSlack": ">=0.1.0"
  }
}
```


----
## Change log
+ **Unreleased**
  - Enable TLS 1.2 when loading the module (if not supported)  
    This is in preparation for a [change in TLS support](https://devblogs.microsoft.com/powershell/powershell-gallery-tls-support/) in the PowerShell Gallery

+ **1.5.1**
  - Improved stability when using an older version of PowerShellGet.
    (We recommend that you continue to update the latest PowerShellGet for the best experience.)  

+ **1.5.0**
  - Add new syntax `pspm install @<Repo>/<Name>` for get modules from specific repository.

+ **1.4.5**
  - Fixed issue that an error occurs when the `pspm install` command was executed simultaneously in multiple processes.
  
+ **1.4.4**
  - Fixed issue that GitHub credential params are not used when downloading modules using `package.json` [#72](https://github.com/mkht/pspm/issues/72)

+ **1.4.3**
  - Improve verbose messages.

+ **1.4.2**
  - Fixed issue that an environment variable `GITHUB_TOKEN` is not working properly.
  - Improve help messages.

+ **1.4.1**
  - Fixed an issue that an error occurs when acquiring a module if invalid folders or files exists in the Modules folder  [#71](https://github.com/mkht/pspm/issues/71)

+ **1.4.0**
  - If an environment variable `GITHUB_TOKEN` is present, pspm uses it as GitHub PAT
  - Exceptions at installing modules has been changed to non-terminating error
  - Improved error messages

+ **1.3.0**
  - Fixed issue that failed to download module from GitHub in macOS [#66](https://github.com/mkht/pspm/issues/66)
  - Download from GitHub private repository [#12](https://github.com/mkht/pspm/issues/12)
  - When acquiring a module from GitHub, pspm will skip download if a module already exists.
  - Added `-NoImport` switch in `pspm install` & `pspm update` [#60](https://github.com/mkht/pspm/issues/60)
  - Fix PSSA issues

+ **1.2.3**
  - Fixed issue that an older version of module has been installed unexpectedly on some environments. [#62](https://github.com/mkht/pspm/issues/62)
  - The pre-release tag comparison process was improved to be equal to [npm-semver](https://docs.npmjs.com/misc/semver#prerelease-tags) [#46](https://github.com/mkht/pspm/issues/46) [#47](https://github.com/mkht/pspm/issues/47)

+ **1.2.1**
  - **Fixed critical issue** that `pspm install` does not function properly in PowerShellGet 1.6+.

+ **1.2.0 (deprecated)**
  - Now warning message displayed when loading modules if your system uses older version of PowerShellGet.
  - Fixed issue that some modules that has pre-release versions fails to install in PowerShell 5.1 and earlier systems. [#61](https://github.com/mkht/pspm/issues/61)
  - Some compatibility improvement

+ **1.1.3**
  - Fixed issue that some modules that has dependencies fails to import. [#59](https://github.com/mkht/pspm/issues/59)

+ **1.1.2**
  - Some compatibility improvement
  - Suppress unneeded output when Module folder created

+ **1.1.0**
  - You can pass any type of objects to `pspm run` arguments

+ **1.0.0**
  - Initial public release

