extends Node

signal card_fixed()
signal card_put_in_bag(card:Card)

# 背包注册/注销信号
signal bag_registered(bag: BagArea)
signal bag_unregistered(bag: BagArea)

# 卡片拖拽信号（用于 BagMover 监听）
signal card_drag_started(card: Card)
signal card_dropped(card: Card)
signal max_layer_changed(max_layer:int)
