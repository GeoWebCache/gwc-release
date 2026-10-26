# Use an official Ruby 2.x image as a base
FROM ruby:2.7

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV EDITOR=vim

# Install dependencies and tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    wget \
    unzip \
    openjdk-11-jdk \
    python3-pip \
    dos2unix \
    vim \
    && rm -rf /var/lib/apt/lists/*

ARG MAVEN_VERSION=3.9.12
# Install Maven
RUN wget https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip -O /tmp/maven.zip && \
    unzip /tmp/maven.zip -d /opt && \
    ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven && \
    ln -s /opt/maven/bin/mvn /usr/bin/mvn && \
    rm /tmp/maven.zip

# Set Maven environment variables
ENV MAVEN_HOME=/opt/maven
ENV PATH=$MAVEN_HOME/bin:$PATH

# Prepare settings.xml file
COPY settings.xml /root/.m2/settings.xml

# Install the latest Sphinx
RUN pip3 install --upgrade pip && \
    pip3 install --upgrade sphinx

# Set Java environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# Clone the GeoWebCache repositories
RUN git clone https://github.com/GeoWebCache/gwc-release.git /root/gwc-release
RUN git clone https://github.com/GeoWebCache/geowebcache.git /root/geowebcache
RUN cp /root/gwc-release/release.rb /root/geowebcache

# Make sure the release.rb dependencies are installed
RUN gem install bundler -v 2.4.22
RUN cd /root/gwc-release && bundle install

# Copy the git setup script into the container
COPY setup_git.sh /usr/local/bin/setup_git.sh

# Make the script executable
RUN dos2unix /usr/local/bin/setup_git.sh && \
	chmod +x /usr/local/bin/setup_git.sh

# Set the script as the entrypoint
ENTRYPOINT ["/usr/local/bin/setup_git.sh"]

# Get in the home directory when the shell is executed
WORKDIR /root

# By default, run a bash shell
CMD ["/bin/bash"]

