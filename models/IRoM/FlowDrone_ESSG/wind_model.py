"""
Wind sensor model from:
FlowDrone: Wind Estimation and Gust Rejection on UAVs Using Fast-Response Hot-Wire Flow Sensors
https://arxiv.org/abs/2210.05857

For more information:
Website / build guide: https://natesimon.github.io/projects/flowdrone/

Example of feedback controller that uses the wind sensor model:
https://github.com/irom-lab/px4_ros_com/blob/other-python/src/offboardController/offboard_control_feedback.py

"""

import torch
from torch import nn
import time

#############################################################################
# Neural network speed estimation model

class NeuralNetworkSpeed(nn.Module):
    '''
    A general/generic Neural Network model class for use with Pytorch. 
    
    '''
    def __init__(self, crosswire=False, fullAngles=False, geom=6):
        super(NeuralNetworkSpeed, self).__init__()
        self.flatten = nn.Flatten()
        
        if crosswire:
            # Architecture to use for crosswire prediction
            # Input size is 3  --- three crosswire features
            # Output size is 2 --- speed (m/s) and angle (rad)
            self.linear_relu_stack = nn.Sequential(
                nn.Linear(3, 25),
                nn.ReLU(),
                nn.Linear(25, 15),
                nn.ReLU(),
                nn.Linear(15, 2),
            )
        else:
            if fullAngles:
                # Architecture to use for angle prediction if the data is dense (2-degree increments)
                # Input size is 6  --- six sensor readings (voltages)
                # Output size is 1 --- angle (rad)
                k1 = int(geom*8)
                k2 = int(k1/2 + 5)
                self.linear_relu_stack = nn.Sequential(
                    nn.Linear(geom, k1),
                    nn.ReLU(),
                    nn.Linear(k1, k2),
                    nn.ReLU(),
                    nn.Linear(k2, 1),
                )
            else:
                # Architecture to use for speed prediction (generally) and for angle prediction 
                # if the data is NOT dense (e.g., is in 10-degree increments)
                # Input size is 6  --- six sensor readings (voltages)
                # Output size is 1 --- either speed (m/s) or angle (rad)

                self.linear_relu_stack = nn.Sequential(
                    nn.Linear(3, 6),
                    nn.ReLU(),
                    nn.Linear(6, 1),
                )

    def forward(self, x):
        # Method to propagate input (reading) through the network to get a prediction. 
        # Terminology is clunky because this is adapted from a classification example, hence 
        # the use of 'logits' even though we are doing regression.
        
        x = self.flatten(x)
        logits = self.linear_relu_stack(x)
        return logits
    
#############################################################################
class NeuralNetworkAngle(nn.Module):
    '''
    A general/generic Neural Network model class for use with Pytorch. 
    
          --- this will allow for custom classes rather than the clunky "if" statement used here. 
    '''
    def __init__(self, crosswire=False, fullAngles=True, geom=6):
        super(NeuralNetworkAngle, self).__init__()
        self.flatten = nn.Flatten()
        
        if crosswire:
            # Architecture to use for crosswire prediction
            # Input size is 3  --- three crosswire features
            # Output size is 2 --- speed (m/s) and angle (rad)
            self.linear_relu_stack = nn.Sequential(
                nn.Linear(3, 25),
                nn.ReLU(),
                nn.Linear(25, 15),
                nn.ReLU(),
                nn.Linear(15, 2),
            )
        else:
            if fullAngles:
                # Architecture to use for angle prediction if the data is dense (2-degree increments)
                # Input size is 6  --- six sensor readings (voltages)
                # Output size is 1 --- angle (rad)
                k1 = int(geom*8)
                k2 = int(k1/2 + 5)
                self.linear_relu_stack = nn.Sequential(
                    nn.Linear(geom, k1),
                    nn.ReLU(),
                    nn.Linear(k1, k2),
                    nn.ReLU(),
                    nn.Linear(k2, 1),
                )
            else:
                # Architecture to use for speed prediction (generally) and for angle prediction 
                # if the data is NOT dense (e.g., is in 10-degree increments)
                # Input size is 6  --- six sensor readings (voltages)
                # Output size is 1 --- either speed (m/s) or angle (rad)
                self.linear_relu_stack = nn.Sequential(
                    nn.Linear(geom, 50),
                    nn.ReLU(),
                    nn.Linear(50, 25),
                    nn.ReLU(),
                    nn.Linear(25, 1),
                )

    def forward(self, x):
        x = self.flatten(x)
        logits = self.linear_relu_stack(x)
        return logits


#############################################################################

# TEST EXAMPLE FOR PENTAGON MODEL
GEOM = 5 # Pentagon Geometry (5 hotwires)

# Separate networks for speed and angle prediction
# Load the speed neural network
model_speed = NeuralNetworkSpeed(crosswire=False, fullAngles=False, geom=GEOM)
opt = torch.optim.Adam(model_speed.parameters(), lr=0.001)
model_speed_path = "speed_network.tar"
checkpoint = torch.load(model_speed_path)
model_speed.load_state_dict(checkpoint['model_state_dict'])
opt.load_state_dict(checkpoint['optimizer_state_dict'])
epoch = checkpoint['epoch']
loss = checkpoint['loss']
model_speed.eval()
# Load the angle neural network
model_angle = NeuralNetworkAngle(crosswire=False, fullAngles=True, geom=GEOM)
opt = torch.optim.Adam(model_angle.parameters(), lr=0.001)
model_angle_path = "angle_network.tar"
checkpoint = torch.load(model_angle_path)
model_angle.load_state_dict(checkpoint['model_state_dict'])
opt.load_state_dict(checkpoint['optimizer_state_dict'])
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

t_start = time.time()
speed_output = model_speed.forward(speed_input)
angle_output = model_angle.forward(angle_input)
t_end = time.time()

print("Speed input: ", speed_input) # 3 most significant (lowest) voltages
print("Speed output: ", speed_output) # speed (m/s)
print("Angle input: ", angle_input) # 5 voltages
print("Angle output: ", angle_output) # angle (radians)
print("Inference time (s): ", t_end - t_start)
