import torch
import torch.nn as nn
from torch import optim
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from torch.nn import functional as F
import torch.quantization

device = "cpu"

class MNISTNet(nn.Module):
    def __init__(self):
        super(MNISTNet, self).__init__()
        self.conv1 = nn.Conv2d(1, 1, kernel_size=3, stride=1, padding=1)
        self.conv2 = nn.Conv2d(1, 1, kernel_size=3, stride=1, padding=1)
        self.fc1 = nn.Linear(7*7, 10)

    def forward(self, x):
        x = F.relu(self.conv1(x))
        x = F.max_pool2d(x, 2)
        x = F.relu(self.conv2(x)) 
        x = F.max_pool2d(x, 2)
        x = x.view(x.size(0), -1)  # Flatten layer
        x = self.fc1(x)
        return x

def quantize_tensor(x):
    # Specify quantization scale and zero_point
    x[x>0.5] = 127
    #x = torch.quantize_per_tensor(x, scale=scale, zero_point=zero_point, dtype=torch.qint8)
    return x
#WRITEME: binary threshold
# Define a transform to normalize the data
transform = transforms.Compose([transforms.ToTensor(),
                                transforms.Resize(320, 240),
                                transforms.Normalize((0.5,), (0.5,)),
                                quantize_tensor])

# Download and load the training data
trainset = datasets.MNIST('.traindata/MNIST_data/', download=True, train=True, transform=transform)
trainloader = DataLoader(trainset, batch_size=64, shuffle=True)

# Define the model
model = MNISTNet().to(device)



# Define the loss
criterion = nn.CrossEntropyLoss()

# Define the optimizer
optimizer = optim.Adam(model.parameters(), lr=0.003)

# Define the number of epochs to train for
epochs = 5

# Train the model
for e in range(epochs):
    running_loss = 0
    for images, labels in trainloader:
        # Clear the gradients
        optimizer.zero_grad()

        # Forward pass, get our log-probabilities
        out = model(images.to(device))

        # Calculate the loss with the logps and the labels
        loss = criterion(out, labels.to(device))

        # Backward pass, compute the gradients
        loss.backward()

        # Take an update step with the optimizer
        optimizer.step()

        running_loss += loss.item()
    else:
        print(f"Training loss: {running_loss/len(trainloader)}")

# Quantize the weights to 8-bit integers
quantized_model = torch.quantization.quantize_dynamic(
    model, {torch.nn.Linear}, dtype=torch.qint8
)

# Download and load the training data
valset = datasets.MNIST('.traindata/MNIST_data/', download=True, train=False, transform=transform)
valloader = DataLoader(valset, batch_size=64, shuffle=True)
# Initialize validation loss
val_loss = 0

# No need to track gradients
with torch.no_grad():
    correct = 0
    total = 0
    for images, labels in valloader:
        # Quantize the images
        quantized_images = quantize_tensor(images)

        # Move the images and labels to the same device as the model
        quantized_images, labels = quantized_images.to(device), labels.to(device)

        # Forward pass
        out = quantized_model(quantized_images)
        _, predicted = torch.max(out.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()
        # Compute validation loss
        loss = criterion(out, labels)

        val_loss += loss.item()

print(f'Validation loss: {val_loss / len(valloader)}, accuracy: {correct/total}')