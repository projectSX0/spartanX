import PackageDescription

var package = Package(
    name: "spartanX",
    dependencies: [.Package(url: "https://github.com/michael-yuji/FoundationPlus.git", versions: Version(0,0,0)..<Version(1,0,0)),
                   .Package(url: "https://github.com/michael-yuji/CKit.git", versions: Version(0,0,0)..<Version(1,0,0)),
                   .Package(url: "https://github.com/michael-yuji/swiftTLS.git", versions: Version(0,0,0)..<Version(1,0,0)),
                   .Package(url: "https://github.com/michael-yuji/XThreads.git", versions: Version(0,0,0)..<Version(1,0,0))]

)

#if os(Linux)
    package.dependencies.append(.Package(url: "https://github.com/michael-yuji/spartanX-linux-include.git", versions: Version(0,0,0)..<Version(1,0,0)))
#endif
