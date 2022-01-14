# Harbour_FastCGI
Framework to create FastCGI apps in Harbour
## How to build and run Docker containars for the example projects
### Echo Example
1. Build from root folder of the project:
`docker build -t echo -f Examples/echo/Dockerfile .`
2. Run Docker container like this:
`docker run --name echo -e TZ=UTC -p 8081:80 echo`
3. Access the webpage from `http://localhost:8081`

### Sandbox Example
1. Build from root folder of the project:
`docker build -t localsandbox -f Examples/LocalSandbox/Dockerfile .`
2. Run Docker container like this:
`docker run --name localsandbox -e TZ=UTC -p 8081:80 localsandbox`
3. Access the webpage from `http://localhost:8081`
