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

# Install Maven 3.9.9
RUN wget https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip -O /tmp/maven.zip && \
    unzip /tmp/maven.zip -d /opt && \
    ln -s /opt/apache-maven-3.9.9 /opt/maven && \
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

# Install XSDDoc (assuming the latest version is 0.11) and fix line endings
RUN wget https://sourceforge.net/projects/xframe/files/xsddoc/xsddoc-1.0/xsddoc-1.0.zip/download -O /tmp/xsddoc.zip && \
    unzip /tmp/xsddoc.zip -d /opt && \
    dos2unix /opt/xsddoc-1.0/bin/xsddoc && \
    chmod +x /opt/xsddoc-1.0/bin/xsddoc && \
    rm /tmp/xsddoc.zip

# Patch XSDDoc to run on Java 11
RUN curl "https://repo1.maven.org/maven2/xerces/xercesImpl/2.12.2/xercesImpl-2.12.2.jar" -o /opt/xsddoc-1.0/lib/xercesImpl.jar

# Set Java environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:/opt/xsddoc-1.0/bin:$PATH

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

