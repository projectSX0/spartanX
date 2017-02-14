import PackageDescription

var package = Package(
    name: "spartanX",
//    targets: [
//        Target(name: "spartanX", dependencies: ["spartanX-include"]),
//        Target(name: "spartanX-include", dependencies: [])
//    ],
    dependencies: [.Package(url: "https://github.com/michael-yuji/FoundationPlus.git", versions: Version(0,0,0)..<Version(1,0,0)),
                   .Package(url: "https://github.com/michael-yuji/CKit.git", versions: Version(0,0,0)..<Version(1,0,0)),
                   .Package(url: "https://github.com/projectSX0/XThreads.git", versions: Version(0,0,0)..<Version(1,0,0)),
		   .Package(url: "https://github.com/projectSX0/spartanX-os-header.git", majorVersion: 0)]
)

