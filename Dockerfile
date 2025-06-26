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
# We'll explicitly run the 'build' script for each package.
# This bypasses `lerna run build` directly and ensures each package builds itself.
# This is a more direct approach if `lerna run build` continues to struggle with context.
RUN cd packages/core && npm run build && cd ../.. && \
    cd packages/cli && npm run build && cd ../..

# Generate the .tgz packages for cli and core components.
# The 'npm pack' command creates the tarball in the current directory (e.g., packages/cli/).
# We use 'cd' to navigate into each package's directory before packing.
RUN cd packages/cli && npm pack && cd ../.. && \
    cd packages/core && npm pack && cd ../..

# --- Final Stage ---
# Use a slim Node.js image for the final runtime environment.
FROM node:24-alpine

# Set the working directory for the application.
WORKDIR /app

# Copy the generated .tgz packages from the 'builder' stage into the final image.
# We're placing them in a temporary location within the container for installation.
COPY --from=builder /app/packages/cli/google-gemini-cli-*.tgz /tmp/gemini-cli.tgz
COPY --from=builder /app/packages/core/google-gemini-cli-core-*.tgz /tmp/gemini-core.tgz
COPY --from=builder /app/.env /app/.env

# Install the packages globally from the copied .tgz files.
RUN npm install -g /tmp/gemini-cli.tgz && \
    npm install -g /tmp/gemini-core.tgz

# Clean up the temporary .tgz files after installation (optional, for slightly smaller image)
RUN rm /tmp/gemini-cli.tgz /tmp/gemini-core.tgz

# Set the default command to run when the container starts.
CMD ["gemini"]