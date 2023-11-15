import sys
import numpy as np

if len(sys.argv) < 2:
    print("Usage: {0} numpy npy matrix to convert".format(sys.argv[0]))

else:
    mat = np.load(sys.argv[1])
    assert len(mat.shape) < 3, "3d and higher dim arrays not supported"

    with open(f'matrix_out.mem', 'w') as f:
        for x in range(mat.shape[0]): # row major
            for y in range(mat.shape[1] // 2):
                f.write(f'{int(mat[x,2*y]):02x}')
                f.write(f'{int(mat[x,2*y+1]):02x}\n')

    print('Matrix saved to matrix_out.mem')

