# pspm - PowerShell Package Manager

pspm is the management tools for PowerShell modules.  
You can manage PowerShell modules [npm](https://www.npmjs.com/) like commands.


## Installation

1. Clone this repository.
1. Copy to PowerShell module directory. (`C:\Program Files\WindowsPowerShell\Modules`)


## Usage

### Install & Import modules

This command will download a module from [PSGallery](https://www.powershellgallery.com/).  
Then save it to a `/Modules` folder in the current directory and import it to the current PS session.

```PowerShell
pspm install '<Module Name>'
pspm install '<Module Name>@<Version>'  #specific version
```

#### Global installation

Install a module as global.  
Module will save to the `$env:ProgramFiles\WindowsPowerShell\Modules`

```PowerShell
pspm install '<Module Name>' -Global
pspm install '<Module Name>' -g
pspm install '<Module Name>' -Scope Global
```

#### User installation

Install a module to current user profile.  
Module will save to the `$env:UserProfile\WindowsPowerShell\Modules`

```PowerShell
pspm install '<Module Name>' -Scope CurrentUser
```

----
### package.json

#### dependencies

You can install multiple modules at once.  
Create `package.json` like below in the current directory. Then run `pspm install`.  

```javascript
{
  "dependencies": {
    "<Module name 1>": "<Version>",
    "<Module name 2>": "<Version>"
  }
}
```

You can use some operators for specifying versions.  

- **version** Must match version exactly. `e.g "1.2.0"`
- **>version** Must be greater than version. `e.g ">1.2.0"`
- **>=version**
- **<version**
- **<=version**
- **latest** Match newest version.
- **\*** Same as **latest**
- **""** (Empty string) Same as **latest**

----
### GitHub URLs

You can download modules from GitHub repos. (Public only)  
Just `<user>/<repo-name>` or `<user>/<repo-name>#<ref>`.  
`<ref>` as `branch` or `commit-hash` or `Tag`  

- **Argument**

```PowerShell
pspm install '<user>/<repo-name>'
pspm install '<user>/<repo-name>#<ref>'
```

- **dependencies in package.json**

```javascript
{
  "dependencies": {
    "<Module name 1>": "<user>/<repo-name>",
    "<Module name 2>": "<user>/<repo-name>#<ref>"
  }
}
```

