import PackageDescription

let package = Package(
    name: "spartanX",
    dependencies: [.Package(url: "https://github.com/michael-yuji/CKit.git", versions: Version(0,0,0)..<Version(1,0,0))]
)
