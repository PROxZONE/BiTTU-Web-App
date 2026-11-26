# BiTTU build status

All Swift sources pass swiftc 6.1.2 -parse with zero errors.

## How to build the app

On macOS:

    git clone https://github.com/PROxZONE/BiTTU-Web-App
    cd BiTTU-Web-App
    ./scripts/make-app.sh

The finished app is at build/BiTTU.app.

CI (build.yml on macos-14) also builds it and uploads BiTTU.app and
BiTTU-Web-App.dmg as artifacts, plus a dated GitHub release.