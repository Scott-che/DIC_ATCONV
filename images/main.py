import torch
import torchvision.transforms as transforms
import torch.nn.functional as F
import torch.nn as nn
from PIL import Image
import numpy as np

path = 'img.dat'
path2 = 'layer0_golden.dat'
path3 = 'layer1_golden.dat'

f = open(path, 'w')
f2 = open(path2, 'w')
f3 = open(path3, 'w')


kernel = torch.tensor([[[[-0.0625, -0.125, -0.0625],
                       [-0.25, 1, -0.25],
                       [-0.0625, -0.125, -0.0625]]]])
bias = torch.tensor([-0.75])


# img = np.array(Image.open('bleach.png'))[:,:,0:3]  ###助教給的一護圖是RGBA，所以讀進來要取前3個channel###
img = np.array(Image.open('./image.jpg'))
img = torch.from_numpy(img).permute(2,0,1)
img = transforms.functional.rgb_to_grayscale(img)
img = transforms.Resize((64,64))(img)


after_padding = nn.ReplicationPad2d(2)(img.float())
after_conv_relu = F.relu(F.conv2d(after_padding.unsqueeze(0), weight=kernel, bias=bias, padding=0, dilation=2, stride=1))
after_max_pooling = nn.MaxPool2d(2,2)(after_conv_relu)
after_max_pooling_roundup = torch.ceil(after_max_pooling)

# print('After conv & relu')
# print(after_conv_relu)

# print('After max-pooling')
# print(after_max_pooling)

# print('After round up')
# print(after_max_pooling_roundup)

for y in range(64):
    for x in range(64):
        bin_integer = bin(after_conv_relu.int().squeeze(0)[0][y][x]).replace('0b','').zfill(9)
        bin_flo = bin(((after_conv_relu.squeeze(0)[0][y][x] - after_conv_relu.int().squeeze(0)[0][y][x])*16).int()).replace('0b','').zfill(4)
        f.write(bin(img[0][y][x]).replace('0b','').zfill(9) + "0000" + "\n")
        f2.write(bin_integer + bin_flo + "\n")

for y in range(32):
    for x in range(32):
        binary_layer1 = bin(after_max_pooling_roundup.int().squeeze(0)[0][y][x]).replace('0b','').zfill(9) + "0000"
        f3.write(binary_layer1 + "\n")

f.close()
f2.close()
f3.close()

