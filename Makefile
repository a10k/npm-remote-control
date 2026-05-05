BINARY_NAME = NpmRemoteControl
BUILD_DIR   = .build/release
APP_NAME    = npm-remote-control.app
APP_OUT     = build/release

.PHONY: build app clean

build:
	swift build -c release

app: build
	mkdir -p $(APP_OUT)
	bash Scripts/build-app.sh $(BUILD_DIR)/$(BINARY_NAME) $(APP_OUT)/$(APP_NAME)

clean:
	rm -rf .build build
