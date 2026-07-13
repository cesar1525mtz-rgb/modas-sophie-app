# Compilación Android

Este proyecto incluye un flujo de GitHub Actions que:
1. instala Flutter 3.44.6 stable;
2. genera el host Android oficial;
3. descarga dependencias;
4. ejecuta flutter analyze;
5. compila app-release.apk;
6. publica el APK como artefacto Modas-Sophie-APK.

No contiene secret key ni service_role.
