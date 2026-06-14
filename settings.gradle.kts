rootProject.name = "OpenCount"

pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

include(":packages:shared")
include(":apps:android")
include(":apps:desktop")
include(":apps:web")
