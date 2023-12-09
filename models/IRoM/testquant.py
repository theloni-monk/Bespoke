import torch.nn as nn
from torch.utils.data import DataLoader
from .datasets import *
from .windnets import *

geometryVal=5
geomPath='pent/'
N=2
epochs0 = 5
ll=4
testPath0 = 'data_agg/test'
loss_fn = nn.L1Loss()

training_data, testing_data, epochs, trainPath, trainLabelPath, testPath, testLabelPath = makeMagDataset(geometryVal=geometryVal, geomPath=geomPath, N=N, testPath0=testPath0, epochs0=epochs0, loocv=ll)
test_dataloader = DataLoader(testing_data, batch_size=1, shuffle=True)

modelPath = 'SavedModels/Velocity/N'
verboseFlag=False

# TEST EXAMPLE FOR PENTAGON MODEL
GEOM = 5 # Pentagon Geometry (5 hotwires)

# Separate networks for speed and angle prediction
# Load the speed neural network
model_speed = MagNet()
model_speed_path = "speed_network.tar"
checkpoint = torch.load(model_speed_path)
model_speed.load_state_dict(checkpoint['model_state_dict'])
epoch = checkpoint['epoch']
loss = checkpoint['loss']
model_speed.eval()
# Load the angle neural network
model_angle = AngleNet()
model_angle_path = "angle_network.tar"
checkpoint = torch.load(model_angle_path)
model_angle.load_state_dict(checkpoint['model_state_dict'])
epoch = checkpoint['epoch']
loss = checkpoint['loss']
model_angle.eval()

#############################################################################

#############################################################################
# Run model on test random input
# NOTE: Speed Input are the 3/5 values with the lowest (most significant) voltage
speed_input = torch.zeros((1,3))
# NOTE: Angle Input are all 5 sensor voltages
angle_input = torch.zeros(1,GEOM)

speed_output = model_speed.forward(speed_input)
angle_output = model_angle.forward(angle_input)

print("Speed input: ", speed_input) # 3 most significant (lowest) voltages
print("Speed output: ", speed_output) # speed (m/s)
print("Angle input: ", angle_input) # 5 voltages
print("Angle output: ", angle_output) # angle (radians)
