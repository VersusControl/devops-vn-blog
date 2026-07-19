---
layout: post
title: "The OSI Model"
series: "Networking for DevOps"
series_url: /networking-series/
part: 1
date: 2024-02-07
author: Quan Huynh
tags: [networking, devops]
image: /assets/images/posts/networking-osi-model/cover.png
---

The OSI (Open Systems Interconnection) model is a reference model that describes
how network systems work. It divides the network communication process into 7
independent layers to improve compatibility and manageability. The layers of the
OSI model are:

- Layer 7: Application
- Layer 6: Presentation
- Layer 5: Session
- Layer 4: Transport
- Layer 3: Network
- Layer 2: Data Link
- Layer 1: Physical

Each layer has a specific function and responsibility in network communication.
This model is widely used to understand how networks work and to help isolate and
troubleshoot network issues. For details on how each layer works, see:
[OSI Model](https://www.geeksforgeeks.org/open-systems-interconnection-model-osi/).

The OSI model we just looked at is a reference model and is used as a way to
describe network architecture. Meanwhile, the model widely applied in practice is
the TCP/IP model (Transmission Control Protocol/Internet Protocol), which is a
condensed version of the OSI model.

The TCP/IP model has 4 layers, starting from the lowest — Physical → Network →
Transport → Application.

![The 4 layers of the TCP/IP model](/assets/images/posts/networking-osi-model/tcp-ip-layers.png)

The layers of the TCP/IP model have the following specific functions:

- **Physical**: Responsible for transmitting data between devices on the same
  network.
- **Network**: Responsible for routing and forwarding data packets between
  different networks.
- **Transport**: Splits large data packets when they are sent and reassembles
  them. This layer ensures data integrity (no errors, no loss, and in the correct
  order).
- **Application**: Where network programs such as web browsers and mail user
  agents operate.
