from udp_ep import UDPFrame

frame = UDPFrame(payload=b'aabb')
frame_content = frame.build_axis().data
print(len(frame_content), frame_content)