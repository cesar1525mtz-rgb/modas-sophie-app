Run flutter build apk --release
Running Gradle task 'assembleRelease'...                        
Checking the license for package CMake 3.22.1 in /usr/local/lib/android/sdk/licenses
License for package CMake 3.22.1 accepted.
Preparing "Install CMake 3.22.1 v.3.22.1".
"Install CMake 3.22.1 v.3.22.1" ready.
Installing CMake 3.22.1 in /usr/local/lib/android/sdk/cmake/3.22.1
"Install CMake 3.22.1 v.3.22.1" complete.
"Install CMake 3.22.1 v.3.22.1" finished.
lib/features/home/seller_dashboard_page.dart:5:8: Error: Error when reading 'lib/data/models/user_profile.dart': No such file or directory
import '../../data/models/user_profile.dart';
       ^
lib/features/home/seller_dashboard_page.dart:6:8: Error: Error when reading 'lib/features/sales/sales_page.dart': No such file or directory
import '../sales/sales_page.dart';
       ^
lib/features/home/seller_dashboard_page.dart:14:9: Error: Type 'UserProfile' not found.
  final UserProfile profile;
        ^^^^^^^^^^^
lib/features/home/seller_dashboard_page.dart:14:9: Error: 'UserProfile' isn't a type.
  final UserProfile profile;
        ^^^^^^^^^^^
lib/features/home/seller_dashboard_page.dart:90:31: Error: Not a constant expression.
        builder: (_) => const SalesPage(),
                              ^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command '/opt/hostedtoolcache/flutter/stable-3.44.6-x64/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to generate a Build Scan (Powered by Develocity).
> Get more help at https://help.gradle.org.

BUILD FAILED in 1m 59s
Running Gradle task 'assembleRelease'...                          119.8s
Gradle task assembleRelease failed with exit code 1
Error: Process completed with exit code 1.
