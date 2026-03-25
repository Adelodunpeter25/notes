.PHONY: help backend desktop mobile build build-preview

help:
	@echo "Available commands:"
	@echo "  make backend        - Start backend server with bun dev"
	@echo "  make desktop        - Start desktop app with bun tauri dev"
	@echo "  make mobile         - Start mobile app with bun start"
	@echo "  make build          - Build desktop app with bun tauri build"
	@echo "  make build-preview  - Build Android preview with EAS"

backend:
	cd server && bun run dev

desktop:
	cd desktop && bun tauri dev

mobile:
	cd mobile && bun start

build:
	cd desktop && bun tauri build

build-preview:
	cd mobile && eas build --platform android --profile preview
