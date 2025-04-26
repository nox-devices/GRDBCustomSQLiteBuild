# Install GRDB with Custom SQLite Build

1. Create a few new directories _inside_ your app project:

    ```bash
    cd path/to/AppProject
    mkdir GRDBCustom
    mkdir GRDBCustom/Binary
    mkdir GRDBCustom/CustomSQLiteConfig
    ```

3. Add GRDB as subtree to your app's repository:

    ```sh
    git remote add grdb https://github.com/groue/GRDB.swift.git
    git fetch grdb --tags
    git subtree add --prefix GRDBCustom/GRDB grdb v7.4.1 --squash
    ```

5. Add [swiftlyfalling/SQLiteLib](https://github.com/swiftlyfalling/SQLiteLib) as a subtree to your app's repository:
    
    - First, we need to delete the `src` folder that GRDB has already created because git expects it to not be there when adding the subtree:

      ```sh
      rm -rf GRDBCustom/GRDB/SQLiteCustom/src
      
      # Must clear the working directory before adding new subtrees, so we commit the changes
      git add -u GRDBCustom/GRDB/SQLiteCustom/src
      git commit -m "Remove placeholder SQLiteCustom/src"
      ```

    - Then, we can add SQLiteLib as subtree:

      ```sh
      git remote add sqlite-custom https://github.com/swiftlyfalling/SQLiteLib.git
      git fetch sqlite-custom --tags
      git subtree add --prefix GRDBCustom/GRDB/SQLiteCustom/src sqlite-custom master --squash
      ```
6. Choose your extra compilation options. For example, `SQLITE_ENABLE_FTS5`, `SQLITE_ENABLE_PREUPDATE_HOOK`.

    It is recommended that you enable the `SQLITE_ENABLE_SNAPSHOT` option. It allows GRDB to optimize [ValueObservation](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/valueobservation) when you use a [Database Pool](https://swiftpackageindex.com/groue/GRDB.swift/documentation/grdb/databasepool).

7. Create four files in the `GRDBCustom/CustomSQLiteConfig` folder:

    - `SQLiteLib-USER.xcconfig`: this file sets the extra SQLite compilation flags.
        
        ```xcconfig
        // As many -D options as there are custom SQLite compilation options
        // Note: there is no space between -D and the option name.
        CUSTOM_SQLLIBRARY_CFLAGS = -DSQLITE_ENABLE_SNAPSHOT -DSQLITE_ENABLE_FTS5
        ```
    
    - `GRDBCustomSQLite-USER.xcconfig`: this file lets GRDB know about extra compilation flags, and enables extra GRDB APIs.
        
        ```xcconfig
        // As many -D options as there are custom SQLite compilation options
        // Note: there is one space between -D and the option name.
        CUSTOM_OTHER_SWIFT_FLAGS = -D SQLITE_ENABLE_SNAPSHOT -D SQLITE_ENABLE_FTS5
        ```
    
    - `GRDBCustomSQLite-USER.h`: this file lets your application know about extra compilation flags.
        
        ```c
        // As many #define as there are custom SQLite compilation options
        #define SQLITE_ENABLE_SNAPSHOT
        #define SQLITE_ENABLE_FTS5
        ```

8. Create one more file in the `GRDBCustom` folder:
    
    - `make_binary.sh`: this file lets your application know about extra compilation flags.
  
        Modify the top of this file so that it contains correct paths. If you followed the folder and file structure above, you shouldn't need to change anything.
        
        ```sh
       #!/bin/bash

      #######################################################
      #                   PROJECT PATHS
      #  !! MODIFY THESE TO MATCH YOUR PROJECT HIERARCHY !!
      #  Paths are relative to the location of this script.
      #######################################################
      
      # The path to the folder containing GRDBCustom.xcodeproj:
      GRDB_SOURCE_PATH="GRDB"
      
      # The path to your custom "SQLiteLib-USER.xcconfig":
      SQLITELIB_XCCONFIG_USER_PATH="CustomSQLiteConfig/SQLiteLib-USER.xcconfig"
      
      # The path to your custom "GRDBCustomSQLite-USER.xcconfig":
      CUSTOMSQLITE_XCCONFIG_USER_PATH="CustomSQLiteConfig/GRDBCustomSQLite-USER.xcconfig"
      
      # The path to your custom "GRDBCustomSQLite-USER.h":
      CUSTOMSQLITE_H_USER_PATH="CustomSQLiteConfig/GRDBCustomSQLite-USER.h"
      
      # The name of the .framework output file (We usually want GRDB.framework)
      FRAMEWORK_NAME="GRDB"
      
      # The directory in which the .framework file will be placed (must be reachable for the Swift Package)
      OUTPUT_PATH="Binary"
      
      # Build configuration. Usually Release is fine.
      CONFIGURATION="Release"
      
      #######################################################
      #
      #######################################################
      
      # The path to the GRDBCustom.xcodeproj file
      GRDB_PROJECT_PATH="${GRDB_SOURCE_PATH}/GRDBCustom.xcodeproj"
      
      # The scheme that builds GRDBCustom
      GRDB_SCHEME_NAME="GRDBCustom"
      
      # Create a temporary build location
      BUILD_DIR="$(mktemp -d)/Build"
      
      #######################################################
      #
      #######################################################
      
      # Helper function to copy over the configuration files
      copy_config_file() {
          local source_file="$1"
          local dest_path="$2"
          local full_source="${source_file}"
          local full_dest="${dest_path}"
      
          if [ ! -f "$full_source" ]; then
              echo "error: Source configuration file missing: $full_source"
              exit 1
          fi
      
          echo "  Copying ${source_file} to ${dest_path}"
          # Create destination directory if it doesn't exist
          mkdir -p "$(dirname "$full_dest")"
          # Copy file preserving metadata
          cp -p "$full_source" "$full_dest"
      }
      
      #######################################################
      # --- Added: detect which platforms to build ----------
      #######################################################
      
      # Normalise incoming arguments to lower-case
      REQUESTED_PLATFORMS=()
      if [ "$#" -eq 0 ]; then
          # If no args: default to *all* supported platforms
          REQUESTED_PLATFORMS=(ios tvos watchos macos catalyst)
      else
          for arg in "$@"; do
              REQUESTED_PLATFORMS+=("$(echo "$arg" | tr '[:upper:]' '[:lower:]')")
          done
      fi
      
      # Helper to check whether a platform was requested
      platform_requested() {
          local needle="$1"
          for p in "${REQUESTED_PLATFORMS[@]}"; do
              if [[ "$p" == "$needle" ]]; then
                  return 0
              fi
          done
          return 1
      }
      
      #######################################################
      #
      #######################################################
      
      # Exit immediately if a command exits with a non-zero status.
      set -e
      
      # --- Sync Custom Config Files ---
      
      echo "Syncing custom configuration files..."
      
      # Define source file names and their destination paths within FRAMEWORK_PROJ_DIR
      copy_config_file "${SQLITELIB_XCCONFIG_USER_PATH}" "${GRDB_SOURCE_PATH}/SQLiteCustom/src/SQLiteLib-USER.xcconfig"
      copy_config_file "${CUSTOMSQLITE_XCCONFIG_USER_PATH}" "${GRDB_SOURCE_PATH}/SQLiteCustom/GRDBCustomSQLite-USER.xcconfig"
      copy_config_file "${CUSTOMSQLITE_H_USER_PATH}" "${GRDB_SOURCE_PATH}/SQLiteCustom/GRDBCustomSQLite-USER.h"
      
      echo "✓ Finished syncing configuration files."
      
      # --- End Sync ---
      
      echo "--- Building XCFramework for ${FRAMEWORK_NAME} ---"
      echo "Framework Project: ${GRDB_PROJECT_PATH}"
      echo "Output Directory: ${OUTPUT_PATH}"
      echo "Build Directory: ${BUILD_DIR}"
      echo "Configuration: ${CONFIGURATION}"
      echo "Requested platforms: ${REQUESTED_PLATFORMS[*]}"
      
      # Ensure output directory exists
      mkdir -p "${OUTPUT_PATH}"
      
      # Clean previous output
      rm -rf "${OUTPUT_PATH}/${FRAMEWORK_NAME}.xcframework"
      
      # Array that will collect all the -framework parameters for -create-xcframework
      XCFRAMEWORK_COMPONENTS=()
      
      #######################################################
      # --- Added: platform-specific build helpers ----------
      #######################################################
      archive_pair() {
          local device_dest="$1"        # e.g. "generic/platform=iOS"
          local sim_dest="$2"           # e.g. "generic/platform=iOS Simulator"
          local base_name="$3"          # e.g. "iphoneos"
          local device_path="${BUILD_DIR}/${FRAMEWORK_NAME}-${CONFIGURATION}-${base_name}.xcarchive"
          local sim_path="${BUILD_DIR}/${FRAMEWORK_NAME}-${CONFIGURATION}-${base_name}sim.xcarchive"
      
          echo "Archiving for ${base_name} Device..."
          xcodebuild archive \
              -project "${GRDB_PROJECT_PATH}" \
              -scheme "${GRDB_SCHEME_NAME}" \
              -configuration "${CONFIGURATION}" \
              -destination "${device_dest}" \
              -archivePath "${device_path}" \
              SKIP_INSTALL=NO \
              BUILD_LIBRARY_FOR_DISTRIBUTION=YES
      
          echo "Archiving for ${base_name} Simulator..."
          xcodebuild archive \
              -project "${GRDB_PROJECT_PATH}" \
              -scheme "${GRDB_SCHEME_NAME}" \
              -configuration "${CONFIGURATION}" \
              -destination "${sim_dest}" \
              -archivePath "${sim_path}" \
              SKIP_INSTALL=NO \
              BUILD_LIBRARY_FOR_DISTRIBUTION=YES
      
          XCFRAMEWORK_COMPONENTS+=("-framework" "${device_path}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework")
          XCFRAMEWORK_COMPONENTS+=("-framework" "${sim_path}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework")
      }
      
      archive_single() {
          local dest="$1"              # e.g. "generic/platform=macOS"
          local base_name="$2"         # e.g. "macos"
          local path="${BUILD_DIR}/${FRAMEWORK_NAME}-${CONFIGURATION}-${base_name}.xcarchive"
      
          echo "Archiving for ${base_name}..."
          xcodebuild archive \
              -project "${GRDB_PROJECT_PATH}" \
              -scheme "${GRDB_SCHEME_NAME}" \
              -configuration "${CONFIGURATION}" \
              -destination "${dest}" \
              -archivePath "${path}" \
              SKIP_INSTALL=NO \
              BUILD_LIBRARY_FOR_DISTRIBUTION=YES
      
          XCFRAMEWORK_COMPONENTS+=("-framework" "${path}/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework")
      }
      
      #######################################################
      # --- Added: perform builds based on arguments --------
      #######################################################
      
      if platform_requested ios; then
          archive_pair "generic/platform=iOS" "generic/platform=iOS Simulator" "iphoneos"
      fi
      
      if platform_requested tvos; then
          archive_pair "generic/platform=tvOS" "generic/platform=tvOS Simulator" "tvos"
      fi
      
      if platform_requested watchos; then
          archive_pair "generic/platform=watchOS" "generic/platform=watchOS Simulator" "watchos"
      fi
      
      if platform_requested macos; then
          archive_single "generic/platform=macOS" "macos"
      fi
      
      if platform_requested catalyst; then
          archive_single "generic/platform=macOS,variant=Mac Catalyst" "catalyst"
      fi
      
      #######################################################
      # --- Create the XCFramework --------------------------
      #######################################################
      
      echo "Creating XCFramework..."
      xcodebuild -create-xcframework \
          "${XCFRAMEWORK_COMPONENTS[@]}" \
          -output "${OUTPUT_PATH}/${FRAMEWORK_NAME}.xcframework"
      
      echo "✓ XCFramework created at: ${OUTPUT_PATH}/${FRAMEWORK_NAME}.xcframework"
      echo "--- XCFramework script finished ---"
        ```
    - You probably need to allow execution for the file:
      ```sh
      chmod +x make_binary.sh
      ```

9. Make the binary:

   ```sh
   # Build only for ios
   ./make_binary.sh ios
   
   # Or build for ios and mac os
   ./make_binary.sh ios macos

   # Or build for all supported platforms
   ./make_binary.sh
   ```

10. Initialize a Swift package that exposes the GRDB binary to your application.

     - Add a `Package.swift` file inside `GRDBCustom`:
  
       ```swift
        // swift-tools-version: 6.0
        
        import PackageDescription
        
        let package = Package(
          name: "GRDBCustom",
          products: [
            .library(
              name: "GRDB",
              targets: ["GRDB"]
            )
          ],
          targets: [
            .binaryTarget(
              name: "GRDB",
              path: "Binary/GRDB.xcframework"
            ),
          ]
        )
       ```

11. Add the Swift package to your project:

    - Drag the entire `GRDBCustom` folder into your app project. Choose "Reference files in place" as action.
  
    - Next, go to your project settings, select your app target, and in the "General" tab, add the `GRDB` target to the "Frameworks, Libraries and Embedded Content" section.
  
12. Now you can use GRDB with your custom SQLite build:

```swift
import GRDB

let dbQueue = try DatabaseQueue(...)
```

## Update GRDB or SQLiteLib

Both GRDB and SQLiteLib are part of the source code in your repository. They are committed and can be used by anyone pulling the repository without having to know about submodules or setting up anything.

To pull updated version of GRDB or SQLiteLib, you can call `git subtree pull`:

```sh
# SQLiteLib
git fetch sqlite-custom --tags
git subtree pull --prefix GRDBCustom/GRDB/SQLiteCustom/src sqlite-custom master --squash

# GRDB
git fetch grdb --tags
git subtree pull --prefix GRDBCustom/GRDB grdb v7.4.1 --squash
```

Make sure to update the binary whenever you pulled a new version:

```sh
./make_binary.sh ios
```

## Load Extensions

> [!NOTE]  
> The first step below will hopefully become a default for the `GRDBCustom` project so that you don't have to do this manually every time. But I have no idea if that if feasible.

> [!NOTE]  
> The second step is inspired by the [SQLiteVec](https://github.com/jkrukowski/SQLiteVec) package that demonstrates how to load SQLite extensions in a Swift package (but using `sqlite3.c` directly, without GRDB as wrapper).

1. To support loading extensions, the `GRDBCustom` project inside the `GRDBCustom/GRDB` folder must expose the `sqlite3ext.h` file.

   - Open the `GRDBCustom` project inside the `GRDBCustom/GRDB` folder.
  
   - Drag the `sqlite3ext.h` file from `GRDBCustom/GRDB/SQLiteCustom/src/sqlite/src` into the project as file _reference_ into the project, where `sqlite3.h` is already references (in the GRDBCustomSQLite group). Add it to the `GRDBCustom` target.
  
   - Go to the project settings, choose the `GRDBCustom` target and go to the "Build Phases" tab. There is a section "Headers". Drag the `sqlite3ext.h` file from the project navigator to the "Public" headers list.
  
   - Got to `GRDB.h` and replace the contents with this:
  
     ```c
     #ifdef __OBJC__
     @import Foundation;
      
     //! Project version number for GRDB.
     FOUNDATION_EXPORT double GRDB_VersionNumber;
      
     //! Project version string for GRDB.
     FOUNDATION_EXPORT const unsigned char GRDB_VersionString[];
     #endif
      
     #ifndef SQLITE_CORE
     #define SQLITE_CORE 1
     #define _GRDB_UNDEF_SQLITE_CORE
     #endif
      
     #import <GRDB/GRDBCustomSQLite-USER.h>
     #import <GRDB/sqlite3.h>
     #import <GRDB/sqlite3ext.h>
     #import "GRDB-Bridging.h"
      
     #ifdef _GRDB_UNDEF_SQLITE_CORE
     #undef SQLITE_CORE
     #undef _GRDB_UNDEF_SQLITE_CORE
     #endif
     ```

     This adds the `sqlite3ext.h` to the umbrella header for the GRDB module. It also makes sure that the Objective-C code in the file is not used when this is imported from a pure C SQlite extension. Finally, it temporarily defines `SQLITE_CORE` to declare the imports. If this is not present, then `grdb-config.h` will fail to compile because the `sqlite3ext.h` messes with the sqlite3_api it sees. This should not affect SQLite at all, it should makes it possible to expose the `sqlite3ext.h` header.

2. Add a "SQLiteExtensions" target to the `GRDBCustom` Swift package.

    - Add a `Sources` folder to `GRDBCustom`:
  
      ```sh
      mkdir Sources
      mkdir Sources/SQLiteExtensions
      ```

   - Add the following files to the `Sources/SQLiteExtensions` folder:
  
       - `initialize-extensions.c`: This files defines a single function that we can call from our app to initializer all SQLite extensions that you want to use:
    
         ```c
         #define SQLITE_CORE 1
         
         #include <GRDB/sqlite3.h> // It is important to not use #include "sqlite3.h", as that will use the iOS build of SQLite
         
         int initialize_sqlite3_extensions() {
           // Initialize all your SQLite extensions
         
           sqlite3_auto_extension(...)
           sqlite3_auto_extension(...)
         }
         ```

     - `include/initialize-extensions.h`: The header of the file:
    
       ```c
       #include <stdio.h>
       #include <GRDB/sqlite3.h>
        
       #ifdef __cplusplus
       extern "C" {
       #endif
        
       int initialize_sqlite3_extensions();
        
       #ifdef __cplusplus
       }
       #endif
       ```

   - Update the `Package.swift` file:
  
     ```swift
      // swift-tools-version: 6.1
      
      import PackageDescription
      
      let package = Package(
        name: "GRDBCustom",
        products: [
          .library(
            name: "SQLiteExtensions",
            targets: ["SQLiteExtensions"]
          ),
          .library(
            name: "GRDB",
            targets: ["GRDB"]
          )
        ],
        targets: [
          .target(
            name: "SQLiteExtensions",
            dependencies: ["GRDB"],
            publicHeadersPath: "include",
            cSettings: [
              .define("SQLITE_CORE", to: "1"),
            ]
          ),
          .binaryTarget(
            name: "GRDB",
            path: "Binary/GRDB.xcframework"
          ),
        ]
      )
     ```

   - Add the `SQLiteExtensions` target to your app target's "Frameworks, Libraries and Embedded Content".

2. Initialize the extensions in your app as early as possible, _before_ initializing or opening a database connection. For example:

   ```swift
    import GRDB
    import SQLiteExtensions
   
    extension AppDatabase {
      static let shared = makeShared()
    
      private static func makeShared() -> AppDatabase {
        do {

          // Initialize the SQLite extensions
          SQLiteExtensions.initialize_sqlite3_extensions()
   
          let fileManager = FileManager.default
          let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
          )
          let directoryURL = appSupportURL.appendingPathComponent("Database", isDirectory: true)
    
          // Create the database folder if needed
          try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    
          // Open or create the database
          let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
          let dbPool = try DatabasePool(
            path: databaseURL.path,
            // Use default AppDatabase configuration
            configuration: AppDatabase.makeConfiguration()
          )
    
          // Create the AppDatabase
          let appDatabase = try AppDatabase(dbPool)
    
          return appDatabase
        } catch {
          fatalError("Critical error: \(error)")
        }
      }
    }
   ```

3. Add and load an SQLite extension. As a demonstration, this guide will use [sqlite-vec](https://github.com/asg017/sqlite-vec), which allows for fast and efficient vector embedding storage and search.

    - Find the source files of the extension. In this example, those are just two files: `sqlite-vec.c` and `sqlite-vec.h`, which you can download by going to the [Releases](https://github.com/asg017/sqlite-vec/releases) page and downloading the amalgamation `.zip` file from "Assets". For example: `sqlite-vec-0.1.7-alpha.2-amalgamation.zip`
  
    - Copy the `sqlite-vec.c` file into `GRDBCustom/Sources/SQLiteExtensions` and the `sqlite-vec.h` file into `GRDBCustom/Sources/SQLiteExtensions/include`.
  
    - **Important**: Those extension files import `sqlite3.h` and `sqlite3ext.h`, which causes the system's default build of SQLite to be used. Therefore, _replace those imports with ones that use the GRDB module_:
  
      ```c
      #import "sqlite3.h" // Before
      #import <GRDB/sqlite3.h> // After
      
      #import "sqlite3ext.h" // Before
      #import <GRDB/sqlite3ext.h> // After
      ```
  
    - Finally, you can add the initialization code. The sqlite-vec extension has a single entry point (most SQLite extensions should have that), in this case it's `sqlite3_vec_init`

      Update the  `GRDBCustom/Sources/SQLiteExtensions/initialize-extensions.c` file to add the initialization call:

         ```c
         #define SQLITE_CORE 1
         
         #include <GRDB/sqlite3.h>
         
         int initialize_sqlite3_extensions() {
           sqlite3_auto_extension((void *)sqlite3_vec_init);
         }
         ```

4. Use the extension

    ```swift
    // Run migration to create the table
    try db.execute(
      sql: """
        create virtual table vec_examples using vec0(
        sample_embedding float[8]
        );
        """
    )
    
    // Insert data
    try db.execute(
      sql: """
        insert into vec_examples(rowid, sample_embedding)
        values
        (1, '[-0.200, 0.250, 0.341, -0.211, 0.645, 0.935, -0.316, -0.924]'),
        (2, '[0.443, -0.501, 0.355, -0.771, 0.707, -0.708, -0.185, 0.362]'),
        (3, '[0.716, -0.927, 0.134, 0.052, -0.669, 0.793, -0.634, -0.162]'),
        (4, '[-0.710, 0.330, 0.656, 0.041, -0.990, 0.726, 0.385, -0.958]');
        """
    )
    
    // Query Data
    let result = try Row.fetchAll(db, sql: """
      select rowid, distance from vec_examples
        where sample_embedding match '[0.890, 0.544, 0.825, 0.961, 0.358, 0.0196, 0.521, 0.175]'
        order by distance
        limit 2;
      """)
    
    print(result)
    ```

## Common Errors

<details>
<summary>Error: Could not build module 'Foundation'</summary>

When compilation fails and you see a range of errors similar to these:

> Error: Could not build module 'GRDB'

> Error: Error: Could not build module 'Foundation'

> Error: Module 'ObjectiveC.NSObject' requires feature 'objc'

> Error: Unexpected '@' in program

Then one likely reason might be that you haven't modified the `GRDB.h` file in the `GRDBCustom` project and it sees Objective-C code like `@import Foundation` that is not supported in pure C.
</details>
