-- Verifies global catalog counts independently of filtered results and pagination.
-- Copyright (c) 2026 Lukianenko Vasyl
-- https://maxpkg.dev
-- Developed by https://3dground.net (3DGROUND)

(
    local testRoot = getFilenamePath (getSourceFileName())
    local runtimeRoot = getFilenamePath (substring testRoot 1 (testRoot.count - 1))
    local iniModule = fileIn (runtimeRoot + @"core\ini.ms")
    local utilsModule = fileIn (runtimeRoot + @"core\utils.ms")
    local repositoryModule = fileIn (runtimeRoot + @"core\repository.ms")
    local managerModule = fileIn (runtimeRoot + @"ui\manager\manager.ms")
    repositoryModule.ini = iniModule
    repositoryModule.utils = utilsModule
    managerModule.utils = utilsModule
    struct CatalogCountTestOwnerData (catalogState = undefined)
    managerModule.owner = CatalogCountTestOwnerData()
    local fixtureId = ((dotNetClass "System.Guid").NewGuid()).ToString()
    local fixturePath = (utilsModule.ensureSlash (getDir #temp)) + "maxpkg-catalog-total-" + fixtureId + ".ini"
    local testCases = #(
        #("split catalog metadata", "[meta]\nPage=2\nPageSize=5\nTotalItems=7\nTotalPages=2\n[Catalog]\nTotalPackages=20\n", 20, 7, 2, 2, 5),
        #("filtered catalog", "[meta]\nTotalItems=500\nTotalPages=21\n[Catalog]\nTotalItems=2\nTotalPages=1\nTotalPackages=1400000\n", 1400000, 2, 1),
        #("empty search result", "[Catalog]\nTotalItems=0\nTotalPages=0\nTotalPackages=1400000\n", 1400000, 0, 0),
        #("empty catalog", "[Catalog]\nTotalItems=0\nTotalPages=0\nTotalPackages=0\n", 0, 0, 0),
        #("legacy catalog", "[Catalog]\nTotalItems=7\nTotalPages=3\n", -1, 7, 3),
        #("legacy metadata", "[meta]\nTotalItems=9\nTotalPages=4\n", -1, 9, 4),
        #("invalid count", "[Catalog]\nTotalPackages=invalid\n", -1, 0, 0),
        #("negative count", "[Catalog]\nTotalPackages=-5\n", -1, 0, 0)
    )
    try (
        for testCase in testCases do (
            if (not (utilsModule.writeText fixturePath testCase[2])) do throw "Could not write the catalog count fixture."
            local responseInfo = repositoryModule.parsePackages fixturePath
            if (not responseInfo.success or responseInfo.totalPackages != testCase[3]) do throw ("Incorrect catalog count: " + testCase[1])
            if (responseInfo.total != testCase[4] or responseInfo.totalPages != testCase[5]) do throw ("Filtered pagination changed: " + testCase[1])
            if (testCase.count > 5 and (responseInfo.page != testCase[6] or responseInfo.pageSize != testCase[7])) do throw "Legacy page and page size were lost. "
            managerModule.owner.catalogState = responseInfo
            local expectedCountJson = if (testCase[3] >= 0) then (testCase[3] as string) else "null"
            if ((findString (managerModule.discoverJson()) ("\"totalPackages\":" + expectedCountJson + ",")) == undefined) do throw ("Catalog count JSON mismatch: " + testCase[1])
        )
        managerModule.owner.catalogState = undefined
        if ((findString (managerModule.discoverJson()) "\"totalPackages\":null") == undefined) do throw "Unloaded catalog has a misleading count."
    ) catch (
        if (doesFileExist fixturePath) do deleteFile fixturePath
        throw()
    )
    if (doesFileExist fixturePath) do deleteFile fixturePath
    format "MAXPKG_CATALOG_TOTAL_OK\n"
    true
)
