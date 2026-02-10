# Contents
- [AI Dev Environment](#ai-development-envitonment-setup)
- [Install Ollama](#install-ollama)
- [Llama3 Hardware Utilization](#llama3-hardware-utilization)
- [AI/ML Dev Tools](#ai-and-ml-dev-tools)

# AI Development Envitonment Setup
Setting up an AI development environment using Conda, CUDA Toolkit, PyTorch, Python, and NVIDIA CUDA drivers on Windows involves several strategic steps to ensure seamless integration and optimal performance. Begin by installing the NVIDIA CUDA drivers compatible with your GPU from the NVIDIA website, ensuring that your system meets the hardware requirements for CUDA. Next, install Anaconda, which simplifies managing Python versions and libraries. Create a new Conda environment and install specific Python versions. Use Conda to install PyTorch with CUDA support, ensuring that the PyTorch version matches the CUDA Toolkit version. This setup allows developers to leverage GPU acceleration for AI and machine learning projects, maximizing computational efficiency.

### Steps:
- Install NVIDIA CUDA Drivers: Download and install from NVIDIA's official site.
- Install Anaconda: Download from the Anaconda website and install.
- Create Conda Environment: `conda create -n aienv python=3.10`
- Activate Environment: `conda activate aienv`
- Install PyTorch with CUDA: `conda install pytorch torchvision torchaudio cudatoolkit=12.1 -c pytorch # (adjust cudatoolkit version as necessary).`
- Verify PyTorch recognizes CUDA:

```python
python
import torch
print(torch.cuda.is_available())  # This should return True
print(torch.__version__) # this should return torch <ver> cuda<ver>, if not, see the troubleshooting steps below
```

### Set Windows System Variables
This process ensures Miniconda3 and its tools are accessible from any command line session, streamlining Python script execution and package management. To set system variables on Windows, particularly for incorporating Miniconda3 into the system PATH, follow these steps:

- Open System Properties:
  - Right-click on the Start button.
  - Click on "System," then "Advanced system settings," and then "Environment Variables."
- Modify the PATH Variable:
  - In the "System Variables" section, scroll to find the "Path" variable.
  - Select it and click "Edit."
- Add Miniconda3 to the PATH:
  - Click "New" and add the Miniconda3 directory path, which is likely C:\ProgramData\miniconda based on your installation.
  - Add the Scripts directory as well: C:\ProgramData\miniconda\Scripts.
- Save and Apply Changes:
  - Click "OK" to close the Edit Environment Variable window, then "OK" again to close the Environment Variables window, and finally "OK" to close the System Properties window.
- Verify Changes:
  - Open a new Command Prompt and type `conda --version` to ensure it's recognized, indicating successful addition to the PATH.

### Troubleshooting Missing CUDA
If the output indicates that your PyTorch installation is the CPU version (e.g. `2.3.0+cpu`), you need to install the CUDA-enabled version of PyTorch to utilize GPU capabilities. Here's how you can fix this:

#### Uninstall the Current PyTorch Version:
Open your terminal or command prompt and run:

```bash
pip uninstall torch torchvision torchaudio
```

#### Install PyTorch with CUDA Support:
Visit the PyTorch Get Started Page to generate the correct install command for your system with CUDA support. Make sure to select the CUDA version compatible with your GPU and system.

For example, if your system supports CUDA 11.3, the command might look like this:

```bash
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu113
```

#### Verify CUDA Installation:
After installation, verify that PyTorch recognizes CUDA:

```python
python
import torch
print(torch.cuda.is_available())  # This should return True
print(torch.__version__) # this should return torch <ver> cuda<ver>, if not, see the steps below
```

This approach ensures that you install the correct version of PyTorch that includes GPU support via CUDA.

# Linux NVIDIA CUDA Drivers
You can choose to download the drivers driectly or install an Ubuntu PopOS with the drivers preloaded.

## PopOS - Ubuntu with NVIDA Drivers
- To save the hassle of a direct NVIDA driver download, you can installe PopOS with NVIDIA drvers baked-in. Go to [System76's website](https://pop.system76.com/), and from the downloads options, select the ISO with NVIDIA.

## Direct NVIDIA Website Install Method

Use the NVIDIA Official Installer:
- If the package manager still doesn't work, you can download the official NVIDIA driver from the NVIDIA website:
  - Visit the NVIDIA Driver Downloads page.
  - Select your GPU model and Linux distribution.
  - Download the runfile (*.run).

> Before running the installer, you might need to stop your display manager: `sudo systemctl stop [display-manager].service  # e.g., gdm3, lightdm, sddm`

- Make the downloaded script executable and run it:

```bash
chmod +x NVIDIA-Linux-x86_64-xxx.xx.run
sudo ./NVIDIA-Linux-x86_64-xxx.xx.run
```

Follow the on-screen instructions to install the driver.
- Reboot and Verify:
```
sudo reboot
```

- After rebooting, check that the NVIDIA driver is correctly installed:
```
nvidia-smi
```

# Install Ollama
See [Ollama Github](https://github.com/ollama/ollama) for instructions.

## Quickstart Install (Linux)
For Linux: use the curl command to install:

```
curl -fsSL https://ollama.com/install.sh | sh
```

## Install LLM
Find your LLM of choice from the [Ollama library](https://ollama.com/library) and download it via Termail with:

```
ollama pull <LLM>

# E.g. ollama pull llama3
```

Ollama supports a list of models available on [ollama.com/library](https://ollama.com/library 'ollama model library')

Here are some example models that can be downloaded:

| Model              | Parameters | Size  | Download                       |
| ------------------ | ---------- | ----- | ------------------------------ |
| Llama 3            | 8B         | 4.7GB | `ollama run llama3`            |
| Llama 3            | 70B        | 40GB  | `ollama run llama3:70b`        |
| Phi-3              | 3.8B       | 2.3GB | `ollama run phi3`              |
| Mistral            | 7B         | 4.1GB | `ollama run mistral`           |
| Neural Chat        | 7B         | 4.1GB | `ollama run neural-chat`       |
| Starling           | 7B         | 4.1GB | `ollama run starling-lm`       |
| Code Llama         | 7B         | 3.8GB | `ollama run codellama`         |
| Llama 2 Uncensored | 7B         | 3.8GB | `ollama run llama2-uncensored` |
| LLaVA              | 7B         | 4.5GB | `ollama run llava`             |
| Gemma              | 2B         | 1.4GB | `ollama run gemma:2b`          |
| Gemma              | 7B         | 4.8GB | `ollama run gemma:7b`          |
| Solar              | 10.7B      | 6.1GB | `ollama run solar`             |

## Customize a Models

### Import from GGUF

Ollama supports importing GGUF models in the Modelfile:

1. Create a file named `Modelfile`, with a `FROM` instruction with the local filepath to the model you want to import.

   ```
   FROM ./vicuna-33b.Q4_0.gguf
   ```

2. Create the model in Ollama

   ```
   ollama create example -f Modelfile
   ```

3. Run the model

   ```
   ollama run example

### Customize a prompt

Models from the Ollama library can be customized with a prompt. For example, to customize the `llama3` model:

```
ollama pull llama3
```

Create a `Modelfile`:

```
FROM llama3

# set the temperature to 1 [higher is more creative, lower is more coherent]
PARAMETER temperature 1

# set the system message
SYSTEM """
You are Mario from Super Mario Bros. Answer as Mario, the assistant, only.
"""
```

Next, create and run the model:

```
ollama create mario -f ./Modelfile
ollama run mario
>>> hi
Hello! It's your friend Mario.
```
   
## Install Huggingface Open-source Community LLMs
To tap into HuggingFacecommunity-created, custom fine-tuned LLM models not supported by Ollama, research AI web GUIs that support such models such as [Oobabooga's TextGen WebUI](https://github.com/oobabooga/text-generation-webui)

## Llama3 Hardware Utilization
> Test was run using `ollama run llama3` not the 70B model.
> Note: When attempting to run the Llama3 70B model with the same specs below, it was at a crawl -- practically unsuable.
![local_llm_specs](https://i.imgur.com/rkeBg62.png)
- For Windows Subsystem Linux:
  - 15GB RAM
  - 32GB RAM (recc'd)
- CPU
  - 6 cores (min)
  - 8 cores(recc'd)
- GPU
![gpu_in_use](https://i.imgur.com/fgHBkot.png)
  - 8GB VRAM GDDR6
  - Tensor Cores: 2880
  - CUDA Cores: 6144
  - Clock Speed: 1.55GHz
  - Memorary Bandwidth: 448GB/s
  - Memory Interface: 256-bit
  - Memory Bus Width: 128-bit
  - Power Consumption (in-use): 40-60W
  - Power Consumption (idle): 12W

# AI and ML Dev Tools
- NVIDIA CUDA Toolkit: NVIDIA's GPU-accelerated deep learning framework.
- PyTorch: Open-source ML library for dynamic computation graph, automatic differentiation, and hardware acceleration for GPUs and TPUs.
- TensorFlow: Open-source ML library for building deep learning networks and training machine learning models.

## NVIDIA CUDA Toolkit
- Check if installed by running:
```
nvcc --version
```
- If the command is not recognized, you must intall the `nvidia-cuda-toolkit`
- To ensure the right version of the CUDA toolkit is installed, it's best to download it directly from [NVIDIA's dev repo](https://developer.nvidia.com/cuda-downloads). In my case, I'll install the 12.4 version:
```
# Add the NVIDIA package repositories
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"
sudo apt-get update

# Install CUDA
sudo apt-get -y install cuda-toolkit-12-4
```

```
sudo apt-get update       # Fetches the list of available updates
sudo apt-get upgrade      # Installs some updates; might hold back some packages
sudo apt-get dist-upgrade # Handles changing dependencies with new versions of packages
```

- Add the following at the end of your `~/.bashrc` or equivalent:

```
nano ~/.bashrc

# add these lines to the end of the file
export PATH=/usr/local/cuda/bin:$PATH
export PATH=/usr/local/cuda/12.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```
- Reload your profile:
```
source ~/.bashrc
```

- Reboot the machine:
```
reboot
```

- After adding the lines and installing, run `nvcc --version` and it should display an output (e.g. `Build cuda_12.4`).

> WIP - Disregard
> ```
> wget https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run
> ```
> - After downloading the runfile, make it executable and run it to install the NVIDIA toolkit:
> - ```
>   # make the runfile executable
>   sudo chmod +x cuda_<version>_linux.run
>   # run the runfile
>   sudo ./cuda_<version>_linux.run
>   ```

## Install Pytorch
- Install `pip`
```
sudo apt install python3-pip
```
PyTorch can be installed directly using pip, but the command depends on your CUDA version if you want GPU support. You can visit the PyTorch Get Started page to generate the correct installation command based on your environment. Below are the general instructions for a common setup:

#### For CPU-only Version:
Run the following command in your terminal:
```
pip install torch torchvision torchaudio
```

#### For CUDA Version:
Replace cuXXX with your CUDA version, e.g., cu124 for CUDA 12.4, and run:

```
pip install torch==x.x.x+cu124 torchvision==x.x.x+cu124 torchaudio==x.x.x+cu124 -f https://download.pytorch.org/whl/torch_stable.html
```

> You don't need to change the `torch_stable.html` URL to select a different CUDA version for PyTorch. The CUDA version is implicitly selected by choosing the correct wheel file that matches your CUDA environment, which pip handles automatically when you specify the `-f`ls flag with the URL.

## Install TensorFlow
TensorFlow offers separate packages for CPU-only and GPU-enabled installations. Make sure to install the version that matches your system's capabilities. For the GPU version, ensure you have the necessary NVIDIA software installed (CUDA and cuDNN).

#### Install TensorFlow for GPU:
`tensorflow-gpu` has been removed, but `tensorflow` works because the [tensorflow](https://pypi.org/project/tensorflow-gpu/) package supports GPU accelerated operations via Nvidia CUDA.
- Run the following command in your terminal:
```
pip install tensorflow
```

> Additional Notes:
> Python Version: Ensure you are using a Python version supported by both TensorFlow and PyTorch. As of now, Python 3.6 to 3.9 are generally supported.
> Virtual Environment: It is highly recommended to install these libraries within a virtual environment to manage dependencies effectively and avoid conflicts with system packages.
> To create and activate a virtual environment, run:
> ```bash
> python -m venv myenv
> source myenv/bin/activate
> ```
> Update pip: Ensure that your pip is up-to-date before installing:
```
pip install --upgrade pip
```
> CUDA/CuDNN: For TensorFlow with GPU, you usually need specific versions of CUDA and cuDNN. Check TensorFlow's official documentation to confirm which versions are required for the latest TensorFlow release.

# Troubleshooting Mismatched CUDA Version
You can confirm a mismatch by running the following: 
```
nvidia-smi       # Your Actual CUDA version
nvcc --version  # Should show CUDA <same version>
```

#### Steps to Resolve the Discrepancy
Aligning your CUDA toolkit version with your driver/runtime version is crucial for ensuring that your deep learning environments are stable and can fully utilize GPU acceleration. This will likely resolve the issue of the LLM defaulting to CPU usage and improve overall performance.

#### Align CUDA Toolkit and Driver Versions
- You have two main options here:
  - Upgrade the CUDA Toolkit: Update your CUDA toolkit to match the installed driver version (CUDA 12.4), which is generally the recommended approach if you want to leverage the latest features and improvements.
  - Downgrade the CUDA Drivers: Revert your CUDA drivers to match the toolkit version you have installed (CUDA 11.5). This might be necessary if you have specific dependencies on the older toolkit version or if newer versions are not yet supported by your applications.

#### Installing or Upgrading CUDA Toolkit
- Download the Newer CUDA Toolkit: Go to the [NVIDIA CUDA Toolkit webpage and download the installer for CUDA 12.4](https://developer.nvidia.com/cuda-downloads), which matches your driver version.
- Installation Instructions: Follow the instructions provided by NVIDIA for installation, which typically include running the downloaded installer and following the on-screen prompts.

#### Post-Installation:
Update your environment variables, if necessary:
```
export PATH=/usr/local/cuda-12.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH
```
- Reboot the system to ensure all changes are applied correctly.

#### Verify the Installation
After installation, verify that the new version is correctly installed and recognized:
```
nvcc --version  # Should now show CUDA 12.4
nvidia-smi       # Should be compatible with CUDA 12.4
```

#### Reinstall Deep Learning Frameworks
With the new CUDA version installed, it's often necessary to reinstall your deep learning frameworks to ensure they are built against the correct CUDA version:
```
pip uninstall tensorflow  # or pytorch
pip install tensorflow-gpu  # or the appropriate pytorch version
```
