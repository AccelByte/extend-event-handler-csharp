# Development container for AccelByte Extend Event Handler
FROM ubuntu:22.04

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

ARG DOTNET_VERSION=8.0

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    #
    # Install essential development tools
    build-essential \
    ca-certificates \
    git \
    sudo \
    wget \
    #
    # Install .NET SDK
    && wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get -y install --no-install-recommends dotnet-sdk-${DOTNET_VERSION} \
    #
    # Install AGS CLI. CARGO_HOME puts the binary in /usr/local/bin, which is
    # already on PATH for every user, so no shell profile has to change.
    && wget --https-only -qO /tmp/ags-installer.sh https://github.com/AccelByte/accelbyte-ags-cli/releases/latest/download/accelbyte-ags-cli-installer.sh \
    && CARGO_HOME=/usr/local ACCELBYTE_AGS_CLI_NO_MODIFY_PATH=1 sh /tmp/ags-installer.sh \
    && rm /tmp/ags-installer.sh \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Set up .NET environment
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH=$DOTNET_ROOT:$DOTNET_ROOT/bin:$PATH

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create user group, user account, and configure passwordless sudo access
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Create workspace directory
RUN mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace

# Switch to non-root user
USER $USERNAME

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

WORKDIR /workspace
