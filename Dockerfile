# Use the official Datadog Agent image
FROM gcr.io/datadoghq/agent:latest
ARG DD_API_KEY

# Copy configuration files
COPY datadog.yaml /etc/datadog-agent/datadog.yaml
COPY conf.d/ /etc/datadog-agent/conf.d/

# Set environment variables (optional)
ENV DD_APM_ENABLED=true
ENV NON_LOCAL_TRAFFIC=true
ENV DD_APM_NON_LOCAL_TRAFFIC=true
ENV DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true
ENV DD_AGENT_MAJOR_VERSION=7

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start-agent"]
 
#  The  datadog.yaml  file is the main configuration file for the Datadog Agent. It contains the API key and other configuration settings. The  conf.d  directory contains additional configuration files for the Agent. 
#  The  Dockerfile  file uses the  gcr.io/datadoghq/agent:latest  image as the base image. It copies the configuration files to the appropriate directories in the container. It also sets some environment variables. 
#  The  ENTRYPOINT  and  CMD  instructions specify the command that the container should run when it starts. 
#  Step 3: Build the Docker image 
#  To build the Docker image, run the following command: 
#  docker build -t datadog-agent .
 
#  This command builds the Docker image using the  Dockerfile  file in the current directory. The  -t  flag specifies the name of the image. 
#  Step 4: Run the Docker container 
#  To run the Docker container, run the following command: 
#  docker run -d --name datadog-agent -e DD_API_KEY=<YOUR_API_KEY> datadog-agent
