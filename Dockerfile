# --- Builder Stage ---
# Use a Node.js image for building the project
FROM node:18-alpine AS builder

# Set the working directory for the build.
# This MUST be the root of the cloned gemini-cli repository, where lerna.json resides.
WORKDIR /app

# Copy the entire source code into the builder stage.
# This ensures all package.json files, lerna.json, and source files are present.
COPY . .

# Install Lerna globally (to use 'lerna run build' etc.)
# Then, install all project dependencies for the monorepo using npm workspaces.
# This replaces the old 'lerna bootstrap' command.
RUN npm install -g lerna && \
    npm install

# Build all packages within the monorepo.
# This will typically compile TypeScript/JavaScript and prepare dist folders.
# This command relies on the 'build' script defined in each package's package.json.
RUN lerna run build

# Generate the .tgz packages for cli and core components.
# The 'npm pack' command creates the tarball in the current directory (e.g., packages/cli/).
# We use 'cd' to navigate into each package's directory before packing.
RUN cd packages/cli && npm pack && cd ../.. && \
    cd packages/core && npm pack && cd ../..

# --- Final Stage ---
# Use a slim Node.js image for the final runtime environment.
# This keeps the final image size smaller as it doesn't include build dependencies.
FROM node:18-alpine

# Set the working directory for the application.
WORKDIR /app

# Copy the generated .tgz packages from the 'builder' stage into the final image.
# We're placing them in a temporary location within the container for installation.
# The `ls -1` is a small trick to find the exact name of the generated tgz file,
# which includes the version number (e.g., google-gemini-cli-1.0.0.tgz).
# Adjust the path if the npm pack output location differs.
COPY --from=builder /app/packages/cli/google-gemini-cli-*.tgz /tmp/gemini-cli.tgz
COPY --from=builder /app/packages/core/google-gemini-cli-core-*.tgz /tmp/gemini-core.tgz

# Install the packages globally from the copied .tgz files.
# The '-g' flag ensures the 'gemini' command is available in the PATH.
RUN npm install -g /tmp/gemini-cli.tgz && \
    npm install -g /tmp/gemini-core.tgz

# Clean up the temporary .tgz files after installation (optional, for slightly smaller image)
RUN rm /tmp/gemini-cli.tgz /tmp/gemini-core.tgz

# Set the default command to run when the container starts.
CMD ["gemini"]