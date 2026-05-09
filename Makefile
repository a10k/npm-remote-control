BINARY_NAME = NpmRemoteControl
BUILD_DIR   = .build/release
APP_NAME    = npm-remote-control.app
DMG_NAME    = npm-remote-control.dmg
APP_OUT     = build/release

.PHONY: build app dmg screenshot clean

build:
	swift build -c release

app: build
	mkdir -p $(APP_OUT)
	bash Scripts/build-app.sh $(BUILD_DIR)/$(BINARY_NAME) $(APP_OUT)/$(APP_NAME)

dmg: app
	bash Scripts/build-dmg.sh $(APP_OUT)/$(APP_NAME) $(APP_OUT)/$(DMG_NAME)

screenshot: app
	bash Scripts/screenshot.sh $(APP_OUT)/$(APP_NAME)

clean:
	rm -rf .build build screenshot.png
