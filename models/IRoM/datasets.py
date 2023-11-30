import torch
from torch.utils.data import DataLoader, Dataset
from torch import nn

import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

class CrossWireDataset(Dataset):
    '''
    Dataset class for pytorch-based learning tailored to crosswire model training. This method
    essentially is feature learning of a specific, reduced set of features from the sensor readings,
    namely:

    [Input Features]
       --- The maximal (absolute) voltage reading (voltage)
       --- The index of the maximal (absolute) voltage reading (integer, {1-6})
       --- The (regularized) ratio of the adjacent sensors (voltage/voltage)
    [Predictions]
       --- The gust speed (m/s)
       --- The gust incident angle (radians)

    '''
    def __init__(self, magFile, angFile, readingsFile, transform=None, target_transform=None):
        # Construct the labels
        tmpMag = pd.read_csv(magFile)
        tmpAng = pd.read_csv(angFile)
        self.mags = torch.Tensor(tmpMag.to_numpy())
        self.angs = torch.Tensor(tmpAng.to_numpy())

        # Construct the features and place them into readings array(X).
        tmpReadings = pd.read_csv(readingsFile)
        tmpReadings = tmpReadings.to_numpy()
        print(tmpReadings.shape)
        LL = tmpReadings.shape[0]
        tmpReadings2 = np.zeros((LL, 3))
        for k in range(LL):
            tmpReadings2[k, 0] = np.max(np.abs(tmpReadings[k, :]))
            tmpReadings2[k, 1] = np.argmax(np.abs(tmpReadings[k, :]))
            tt = int(tmpReadings2[k,1])
            tmpReadings2[k, 2] = np.abs(tmpReadings[k, (tt-1)%6])/(np.abs(tmpReadings[k, (tt+1)%6]) + 0.05)

        self.readings = torch.Tensor(tmpReadings2)

        # Incorporate the transforms as needed
        self.transform=transform
        self.target_transform = target_transform

    def __len__(self):
        return len(self.mags)

    def __getitem__(self, idx):
        reading = self.readings[idx, :]
        mag = self.mags[idx]
        ang = self.angs[idx]
        label = torch.cat((mag, ang), 0)

        if self.transform:
            reading = self.transform(reading)
        if self.target_transform:
            label = self.target_transform(label)

        return reading, label

class WindMagDataset(Dataset):
    '''
    Dataset class for pytorch-based learning for gust magnitude data training. This method
    learns directly from the sensor readings (voltages) to predict gust speed (m/s).
    [Inputs]
       --- The sensor readings (voltages)
    [Predictions]
       --- The gust speed (m/s)
    '''
    def __init__(self, magFile, readingsFile, loocv=None, geomVal=5, isTest=False, transform=None, target_transform=None):
        basicLoocv = False

        if loocv is None:
            tmpMag = pd.read_csv(magFile, header=None)
            tmpReadings = pd.read_csv(readingsFile, header=None)
            self.mags = torch.Tensor(tmpMag.to_numpy())
            self.readings = torch.Tensor(tmpReadings.to_numpy())
            # print(self.mags.shape)
            # print(self.readings.shape)
        else:
            if basicLoocv:
                if geomVal==3:
                    namesArray=['S1', 'S2', 'S3']
                elif geomVal==4:
                    namesArray=['S1', 'S2', 'S3', 'S4']
                elif geomVal==5:
                    namesArray=['S1', 'S2', 'S3', 'S4', 'S5']
                elif geomVal==6:
                    namesArray=['S1', 'S2', 'S3', 'S4', 'S5', 'S6']
                else:
                    raise ValueError(f"geomVal is {geomVal:>2f}, but must be one of {{3, 4, 5, 6}}")

                tmpMag = pd.read_csv(magFile, names=['Vel'])
                tmpReadings = pd.read_csv(readingsFile, names=namesArray)
                # print(tmpMag.shape)
                # print(tmpReadings.shape)
                tmpBig = pd.concat([tmpMag, tmpReadings], axis=1)
                if isTest:
                    df = tmpBig[(tmpBig['Vel'].between(speedArray[loocv]-0.01, speedArray[loocv]+0.01))]
                    # print(df)
                    self.mags = torch.Tensor((df.iloc[:,0:1]).to_numpy())
                    # self.mags = torch.Tensor((df['Vel']).to_numpy())
                    self.readings = torch.Tensor((df.iloc[:,1:]).to_numpy())
                    # self.readings = torch.Tensor(df[['S1', 'S2', 'S3']].to_numpy())
                    # print(self.mags.shape)
                    # print(self.readings.shape)
                else:
                    df = tmpBig[~(tmpBig['Vel'].between(speedArray[loocv]-0.01, speedArray[loocv]+0.01))]
                    # print(df)
                    self.mags = torch.Tensor((df.iloc[:,0:1]).to_numpy())
                    # self.mags = torch.Tensor((df['Vel']).to_numpy())
                    self.readings = torch.Tensor((df.iloc[:,1:]).to_numpy())
                    # self.readings = torch.Tensor(df[['S1', 'S2', 'S3']].to_numpy())
                    # print(self.mags.shape)
                    # print(self.mags[0])
                    # print(self.readings.shape)
                    # print(self.readings[0,:])
            else:
                tmpMag = pd.read_csv(magFile, names=None).to_numpy()
                if isTest:
                    indList = np.argwhere(((tmpMag > speedArray[loocv]-0.01) & (tmpMag < speedArray[loocv]+0.01)))[:,0]
                else:
                    indList = np.argwhere(((tmpMag < speedArray[loocv]-0.01) | (tmpMag > speedArray[loocv]+0.01)))[:,0]

                tmpReadings0 = pd.read_csv(readingsFile, names=None).to_numpy()
                tmpReadings = np.flip(np.sort(np.abs(tmpReadings0), axis=1), axis=1)[indList,:3]
                self.mags = torch.Tensor(tmpMag[indList,:])
                self.readings = torch.Tensor(tmpReadings)


        # breakpoint()
        # Incorporate the transforms as needed
        self.transform=transform
        self.target_transform = target_transform

    def __len__(self):
        return len(self.mags)

    def __getitem__(self, idx):
        reading = self.readings[idx, :]
        label = self.mags[idx]
        if self.transform:
            reading = self.transform(reading)
        if self.target_transform:
            label = self.target_transform(label)

        return reading, label
class WindAngDataset(Dataset):
    '''
    Dataset class for pytorch-based learning for gust angle data training. This method
    learns directly from the sensor readings (voltages) to predict gust incidence angle (radians).
    [Inputs]
       --- The sensor readings (voltages)
    [Predictions]
       --- The gust angle (rad)
    '''
    def __init__(self, angFile, readingsFile, transform=None, target_transform=None):
        tmpAng = pd.read_csv(angFile)
        tmpReadings = pd.read_csv(readingsFile)
        self.angs = torch.Tensor(tmpAng.to_numpy())
        self.readings = torch.Tensor(tmpReadings.to_numpy())

        # Incorporate the transforms as needed
        self.transform=transform
        self.target_transform = target_transform

    def __len__(self):
        return len(self.angs)

    def __getitem__(self, idx):
        reading = self.readings[idx, :]
        label = self.angs[idx]
        if self.transform:
            reading = self.transform(reading)
        if self.target_transform:
            label = self.target_transform(label)

        return reading, label
class WindAngTrigDataset(Dataset):
    '''
    Dataset class for pytorch-based learning for gust angle data training. This method
    learns directly from the sensor readings (voltages) to predict gust incidence angle (radians).
    [Inputs]
       --- The sensor readings (voltages)
    [Predictions]
       --- The gust angle (rad)
    '''
    def __init__(self, angFile, readingsFile, transform=None, target_transform=None):
        tmpAng = pd.read_csv(angFile)
        tmpReadings = pd.read_csv(readingsFile)
        numpyAngs = tmpAng.to_numpy()
        self.angs = torch.Tensor(np.array((np.cos(numpyAngs), np.sin(numpyAngs))))
        self.readings = torch.Tensor(tmpReadings.to_numpy())

        # Incorporate the transforms as needed
        self.transform=transform
        self.target_transform = target_transform

    def __len__(self):
        return len(self.angs[:, 0])

    def __getitem__(self, idx):
        reading = self.readings[idx, :]
        label = self.angs[idx, :]
        if self.transform:
            reading = self.transform(reading)
        if self.target_transform:
            label = self.target_transform(label)

        return reading, label
def makeAngleDataset(trigValue=1, geomPath='/hex', N=1, testPath0=None, epochs0=15):

    # training data paths are fixed
    trainPathBase = 'data_agg/train'
    trainLabelPath = trainPathBase+'/'
    trainPath=trainPathBase+'_N'+str(N)+'/'

    # testing data paths -- set to validation data for hyperparam tuning, else test data
    testPathBase = 'data_agg/val' if testPath0 is None else testPath0
    testLabelPath = testPathBase+'/'
    testPath= testPathBase+'_N'+str(N)+'/'

    # Fix angle dataset paths
    trainY = trainLabelPath+'angsrad.csv'
    trainX = trainPath+geomPath+'readings.csv'
    testY = testLabelPath+'angsrad.csv'
    testX = testPath+geomPath+'readings.csv'

    # Figure out trig option and make the datasets
    if trigValue == 1:
        training_data = WindAngDataset(trainY, trainX, transform=None)
        testing_data = WindAngDataset(testY, testX, transform=None)
    else:
        training_data = WindAngTrigDataset(trainY, trainX, transform=None)
        testing_data = WindAngTrigDataset(testY, testX, transform=None)

    epochs = epochs0

    return training_data, testing_data, epochs, trainPath, trainLabelPath, testPath, testLabelPath
def makeMagDataset(geometryVal=6, geomPath='/hex', N=1, testPath0=None, epochs0=15, loocv=None):
    # Make dataset
    # Change this as desired in {1, 2, 3, 4, 5}
    #
    # INDEX:
    #   --- (1) Sparse wind magnitudes                         [OLD]
    #   --- (2) Sparse wind angles (10-degree increments)      [OLD]
    #   --- (3) Dense Crosswire Model
    #   --- (4) Dense Wind Magnitudes
    #   --- (5) Dense Incidence Angles (2-degree increments)

    ### dataSetType = 2

    # 3=Triangle, 4=Square, 5=Pentagon, 6=Hexagon
    ### geometryVal = 3
    ### compFlag=True
    ### N = 1                 # Number of sequentially averaged data points

    trainPathBase = 'data_agg/train'
    trainLabelPath = trainPathBase+'/'
    trainPath = trainPathBase+'_N'+str(N)+'/'

    testPathBase = 'data_agg/val' if testPath0 is None else testPath0
    testLabelPath = testPathBase+'/'
    testPath = testPathBase+'_N'+str(N)+'/'       # Set to validation data for network/hyperparameter optimization, else test data

    trainY = trainLabelPath+'mags.csv'
    trainX = trainPath+geomPath+'readings.csv'
    testY = trainLabelPath+'mags.csv'
    testX = trainPath+geomPath+'readings.csv'
    training_data = WindMagDataset(trainY, trainX, loocv=loocv, geomVal=geometryVal, isTest=False, transform=None)
    testing_data = WindMagDataset(testY, testX, loocv=loocv, geomVal=geometryVal, isTest=True, transform=None)

    epochs = epochs0

    return training_data, testing_data, epochs, trainPath, trainLabelPath, testPath, testLabelPath