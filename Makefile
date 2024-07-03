PORT = 3000
IP := $(shell ifconfig | grep -Eo 'inet (addr:)?([0-9]\.){3}[0-9]' | grep -Eo '([0-9]\.){3}[0-9]' | grep -v '127.0.0.1' | awk '{print $1}')

run-no-sec:
	@flutter run -d chrome --web-port=$(PORT) --web-browser-flag "--disable-web-security"

run-ns: run-no-sec

serve:
	@flutter run -d web-server --web-port=$(PORT)

serve-ip:
	@flutter run -d web-server --web-hostname=$(IP) --web-port=$(PORT)

run:
	@flutter run -d chrome --web-port=$(PORT)

build: clean
	@flutter build web --web-renderer=canvaskit

release: clean
	@flutter build web --release --web-renderer=canvaskit

fvm-release: clean
	@fvm flutter build web --release --web-renderer=canvaskit

fvm-run:
	@fvm flutter run -d chrome --web-port=$(PORT)

clean:
	@rm -rf build/web

web-verbose:
	@flutter run -d chrome --web-port=$(PORT) --verbose

tcp:
	@flutter run -d web-server --web-port=3000 --web-renderer=canvaskit

.PHONY: clean run run-no-sec run-ns 
