# Install requirements
pip install -r requirements.txt

# Function to check file existence
function Verify-File {
    param ([string]$Path)
    if (-Not (Test-Path $Path)) {
        Write-Host "Missing file: $Path"
        Write-Host "Please ensure the file structure is correct or download the file."
        exit 1
    }
}

# Function to check directory existence
function Verify-Dir {
    param ([string]$Path)
    if (-Not (Test-Path $Path)) {
        Write-Host "Creating missing directory: $Path"
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

# Function to install Chocolatey
function Install-Chocolatey {
    Write-Host "Chocolatey not found. Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey installation failed. Please install Chocolatey manually."
        exit 1
    }
    Write-Host "Chocolatey installed successfully."
}

# Check for Chocolatey
if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Install-Chocolatey
} else {
    Write-Host "Chocolatey is already installed. Skipping."
}

# Upgrade pip and install dependencies
Write-Host "Upgrading pip..."
pip install --upgrade pip
Write-Host "Installing dependencies..."
pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 xformers==0.0.28.post3 --index-url https://download.pytorch.org/whl/cu124
pip install torchao --index-url https://download.pytorch.org/whl/nightly/cu124
if (Test-Path "requirements.txt") {
    pip install -r requirements.txt
} else {
    Write-Host "requirements.txt not found. Skipping requirements installation."
}
pip install --no-deps facenet_pytorch==2.6.0

# Install FFmpeg
if (-Not (Test-Path "ffmpeg-4.4-amd64-static")) {
    Write-Host "Downloading and extracting FFmpeg..."
    Invoke-WebRequest -Uri https://www.johnvansickle.com/ffmpeg/old-releases/ffmpeg-4.4-amd64-static.tar.xz -OutFile ffmpeg-4.4-amd64-static.tar.xz
    tar -xf ffmpeg-4.4-amd64-static.tar.xz
} else {
    Write-Host "FFmpeg already downloaded and extracted. Skipping."
}
$env:FFMPEG_PATH = (Get-Location).Path + "\ffmpeg-4.4-amd64-static"

# Initialize git LFS and clone pretrained weights
if (-Not (git lfs env 2>&1 | Out-Null)) {
    Write-Host "Initializing Git LFS..."
    git lfs install
} else {
    Write-Host "Git LFS already initialized. Skipping."
}

if (-Not (Test-Path "pretrained_weights")) {
    Write-Host "Cloning pretrained weights repository..."
    git clone https://huggingface.co/BadToBest/EchoMimicV2 pretrained_weights
} else {
    Write-Host "Pretrained weights directory already exists. Skipping clone."
}

# Clone additional repositories
Write-Host "Verifying additional repositories..."
Verify-Dir "./pretrained_weights/sd-vae-ft-mse"
if ((Get-ChildItem "./pretrained_weights/sd-vae-ft-mse" -Recurse | Measure-Object).Count -eq 0) {
    git clone https://huggingface.co/stabilityai/sd-vae-ft-mse ./pretrained_weights/sd-vae-ft-mse
} else {
    Write-Host "sd-vae-ft-mse repository already exists. Skipping clone."
}

Verify-Dir "./pretrained_weights/sd-image-variations-diffusers"
if ((Get-ChildItem "./pretrained_weights/sd-image-variations-diffusers" -Recurse | Measure-Object).Count -eq 0) {
    git clone https://huggingface.co/lambdalabs/sd-image-variations-diffusers ./pretrained_weights/sd-image-variations-diffusers
} else {
    Write-Host "sd-image-variations-diffusers repository already exists. Skipping clone."
}

# Verify required model files in pretrained_weights
Write-Host "Checking required model files in pretrained_weights..."
Verify-File "./pretrained_weights/denoising_unet.pth"
Verify-File "./pretrained_weights/reference_unet.pth"
Verify-File "./pretrained_weights/motion_module.pth"
Verify-File "./pretrained_weights/pose_encoder.pth"

# Set up audio processor inside pretrained_weights and download tiny.pt
$AudioProcessorDir = "./pretrained_weights/audio_processor"
Verify-Dir $AudioProcessorDir
Set-Location -Path $AudioProcessorDir
if (-Not (Test-Path "tiny.pt")) {
    Write-Host "Downloading tiny.pt model..."
    Invoke-WebRequest -Uri https://openaipublic.azureedge.net/main/whisper/models/65147644a518d12f04e32d6f3b26facc3f8dd46e5390956a9424a650c0ce22b9/tiny.pt -OutFile tiny.pt
} else {
    Write-Host "tiny.pt model already exists. Skipping download."
}
Set-Location -Path (Get-Location).Parent.Parent

# Install FFmpeg Environment
if (-Not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "Installing FFmpeg environment..."
    choco install ffmpeg -y
} else {
    Write-Host "FFmpeg environment already installed. Skipping."
}

Write-Host "Setup complete!"
