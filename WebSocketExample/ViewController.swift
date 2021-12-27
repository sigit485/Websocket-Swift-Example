//
//  ViewController.swift
//  WebSocketExample
//
//  Created by CODE.ID on 24/12/21.
//

import UIKit

struct Coin {
    var name: String
    var price: String
}

class ViewController: UIViewController {
    
    private var websocket: URLSessionWebSocketTask?
    
    private var coins: [Coin] = [] {
        didSet {
            DispatchQueue.main.async {
                self.myTableView.reloadData()
            }
        }
    }
    
    private let closeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.setTitle("Close", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 8.0
        button.clipsToBounds = true
        return button
    }()
    
    private var myTableView: UITableView!
    
    private var isConnected: Bool = true
    
    var session: URLSession?
    
    let url = URL(string: "wss://ws.coincap.io/prices?assets=ALL")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .lightGray
        
        session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: OperationQueue())
        
        self.connect()
        
        view.addSubview(closeButton)
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        
        let barHeight: CGFloat = UIApplication.shared.statusBarFrame.size.height
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        
        myTableView = UITableView(frame: CGRect(x: 0, y: barHeight, width: displayWidth, height: displayHeight - barHeight))
        myTableView.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
        myTableView.dataSource = self
//        myTableView.delegate = self
        self.view.addSubview(myTableView)
        
        myTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: myTableView!, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: myTableView!, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: myTableView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: barHeight),
            NSLayoutConstraint(item: myTableView!, attribute: .bottom, relatedBy: .equal, toItem: closeButton, attribute: .top, multiplier: 1, constant: -8)
        ])
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: closeButton, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 14),
            NSLayoutConstraint(item: closeButton, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: -14),
            NSLayoutConstraint(item: closeButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 50),
            NSLayoutConstraint(item: closeButton, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: -30)
        ])
    }
    
    
    func ping() {
        websocket?.sendPing(pongReceiveHandler: { error in
            if let error = error {
                print("Ping error: \(error)")
            }
        })
    }
    
    @objc
    func close() {
        if isConnected {
            disconnect()
            isConnected = false
            closeButton.setTitle("Connect", for: .normal)
        } else {
            connect()
            isConnected = true
            closeButton.setTitle("Close", for: .normal)
        }
    }
    
    func connect() {
        websocket = session?.webSocketTask(with: url!)
        websocket?.resume()
    }
    
    func disconnect() {
        websocket?.cancel(with: .goingAway, reason: "Demo ended".data(using: .utf8))
    }
    
    func send() {
        DispatchQueue.global().asyncAfter(deadline: .now()+1) {
            self.send()
            self.websocket?.send(.string("Send new data"), completionHandler: { error in
//                (error as NSError).code
                if let _error = error as NSError? {
                    if _error.code == 53 {
                        self.connect()
                    } else {
                        print("Send error: \(_error)")
                        self.connect()
                    }
                } else {
                    if let error = error {
                        print("Send error: \(error)")
                    }
                }
            })
        }
    }
    
    func receive() {
        websocket?.receive(completionHandler: { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    print("Got data: \(data)")
                case .string(let message):
                    print("Got string: \(message)")
                    let data = message.data(using: .utf8)
                    let anyObjc: AnyObject? = try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.init(rawValue: 0)) as AnyObject
                    
                    if let _anyObj = anyObjc {
                        self?.coins = (self?.parseJSON(anyObj: _anyObj))!
                    }
                @unknown default:
                    break
                }
            case .failure(let error):
                print("Receive error \(error)")
                self?.connect()
            }
            
            self?.receive()
        })
    }
    
    func parseJSON(anyObj: AnyObject) -> [Coin] {
        var list: [Coin] = []
        
        if anyObj is NSDictionary {
            for (key, value) in anyObj as! NSDictionary {
                list.append(
                    Coin(name: key as! String,
                         price: value as! String))
            }
        }
        return list
    }


}

extension ViewController: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Did connect to socket")
        ping()
        receive()
        send()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Did close connection with reason \(closeCode.rawValue)")
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coins.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "MyCell")
        cell.textLabel!.text = "\(coins[indexPath.row].name)"
        cell.detailTextLabel?.text = "price: \(coins[indexPath.row].price)"
        cell.detailTextLabel?.textColor = .systemBlue
        return cell
    }
}
