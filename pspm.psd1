@{
    # Version number of this module.
    ModuleVersion     = '1.4.3'

    # ID used to uniquely identify this module
    GUID              = '43b54a10-c2d7-45b1-b46f-9a9da9da1c39'

    # Author of this module
    Author            = 'mkht'

    # Script module or binary module file associated with this manifest.
    RootModule        = 'pspm.psm1'

    # Company or vendor of this module
    CompanyName       = ''

    # Copyright statement for this module
    Copyright         = '(c) 2018 mkht. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell Package Manager'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Functions to export from this module
    FunctionsToExport = @('pspm')

    # Format files (.ps1xml) to be loaded when importing this module.
    FormatsToProcess  = @('./Class/pspm.SemVer.format.ps1xml')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('npm', 'PackageManagement')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/mkht/pspm/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/mkht/pspm'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Fixed an issue that an error occurs when acquiring a module if invalid folders or files exists in the Modules folder'

        } # End of PSData hashtable

    } # End of PrivateData hashtable
}
