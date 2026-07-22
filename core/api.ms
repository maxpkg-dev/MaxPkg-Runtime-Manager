(
    struct MaxPkgApiModule (
        fn resolve packages packageReference = (
            if packageReference == undefined do return undefined
            if isProperty packageReference #guid do (
                if packageReference.guid != undefined and packageReference.guid != "" do return packageReference
            )
            local packageKey = toLower (packageReference as string)
            for package in packages where (toLower package.guid) == packageKey or (toLower package.slug) == packageKey do return package
            return undefined
        ),

        fn contains packages guid = (
            return (resolve packages guid) != undefined
        )
    )

    MaxPkgApiModule()
)
