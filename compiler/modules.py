from abc import ABC

class MLModule(ABC):
    name: str
    in_nodes: list
    out_nodes: list
    visited: bool # for dfs traversal
    hyperparams: list
    params: list

    def __init__(self, in_nodes:list, out_nodes:list):
        self.in_nodes = in_nodes
        self.out_nodes = out_nodes
        self.visited = False

    def __repr__(self):
        return self.name

    def systemverilog(self):
        raise NotImplementedError

    @property
    def is_source(self):
        return self.in_nodes is []

    @property
    def is_sink(self):
        # handles recurrent relations by defining a node with already visited outputs as terminal
        if self.out_nodes is []:
            return True
        onodes_visited = True
        for node in self.out_nodes:
            onodes_visited &= node.visited
        return onodes_visited

#TODO: figure out fifo connectivity
class MVProd(MLModule):
    def __init__(self, inodes, onodes, instance_num):
        super().__init__(inodes, onodes)
        self.name = str(self) + str(instance_num)

    def systemverilog(self):
        return f"""
                """