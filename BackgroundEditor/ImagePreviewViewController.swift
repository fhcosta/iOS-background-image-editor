//
//  ImagePreviewViewController.swift
//  BackgroundEditor
//
//  Created by cmcmillan on 7/04/21.
//

import Foundation
import UIKit

import VideoToolbox

class ImagePreviewViewController: UIViewController {
    var imageURL: URL// = Bundle.main.url(forResource: "IMG_1311", withExtension: "heic")!
    let previewImageView = UIImageView()
    
    let colors: [UIColor] = [.white, .black, .red, .orange, .yellow, .green, .blue, .purple]
    
    var selectedColor: UIColor {
        didSet {
            previewImageView.backgroundColor = selectedColor
        }
    }
    
    var depthSlider: UISlider = UISlider()

    /// The sample resource currently being displayed.
    var currentSampleImage: SampleImage? = nil

    /// The context used for filtering images.
    let context = CIContext()

    /// A collection of filter methods that can be applied to images.
    lazy var depthFilters = DepthImageFilters(context: context)
    
    lazy var colorCarousel: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8.0
        let carousel = UICollectionView(frame: view.frame, collectionViewLayout: layout)
        carousel.translatesAutoresizingMaskIntoConstraints = false
        carousel.showsVerticalScrollIndicator = false
        carousel.showsHorizontalScrollIndicator = false
        carousel.delegate = self
        carousel.dataSource = self
        ColorCollectionViewCell.register(in: carousel)
        carousel.contentInset = .init(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
        carousel.backgroundColor = .clear
        return carousel
    }()
    
    init(imageURL: URL) {
        self.imageURL = imageURL
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupColorCarousel()
        setupDepthSlider()
        loadSample(withFileURL: imageURL)
    }
    
    func setupImageView() {
        previewImageView.backgroundColor = selectedColor
        previewImageView.clipsToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewImageView)
        NSLayoutConstraint.activate([previewImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                     previewImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     previewImageView.topAnchor.constraint(equalTo: view.topAnchor),
                                     previewImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.isUserInteractionEnabled = true
        previewImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleUI)))
    }
    
    func setupColorCarousel() {
        colorCarousel.backgroundColor = .clear
        view.addSubview(colorCarousel)
        NSLayoutConstraint.activate([colorCarousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                     colorCarousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     colorCarousel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                                     colorCarousel.heightAnchor.constraint(equalToConstant: 50)])
        colorCarousel.setNeedsLayout()
        colorCarousel.layoutIfNeeded()
    }
    
    func setupDepthSlider() {
        depthSlider.value = 0.8
        depthSlider.translatesAutoresizingMaskIntoConstraints = false
        depthSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        view.addSubview(depthSlider)
        NSLayoutConstraint.activate([depthSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
                                     depthSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                                     depthSlider.bottomAnchor.constraint(equalTo: colorCarousel.topAnchor, constant: -16)])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        do {
            try FileManager.default.removeItem(at: imageURL)
        } catch {
            print("Could not remove file at url: \(imageURL)")
        }
    }
   
    @objc
    func toggleUI() {        
        UIView.animate(withDuration: 0.3) {
            self.navigationController?.setNavigationBarHidden(!(self.navigationController?.navigationBar.isHidden ?? true), animated: true)
            self.depthSlider.alpha = self.depthSlider.alpha == 0.0 ? 1.0 : 0.0
            self.colorCarousel.alpha = self.colorCarousel.alpha == 0.0 ? 1.0 : 0.0
        }
    }
}

extension ImagePreviewViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorCollectionViewCell.reuseIdentifier, for: indexPath) as! ColorCollectionViewCell
        cell.configure(with: colors[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let color = colors[safe: indexPath.item] {
            selectedColor = color
        }
    }
}

// MARK: Helper Methods
extension ImagePreviewViewController {
    func loadSample(withFileURL url: URL) {
        // Load the sample image
        guard let image = SampleImage(url: url) else { return }
        currentSampleImage = image
        // Update the image view
        updateView()
    }
    
    func updateView() {
        guard let sampleImage = currentSampleImage else { return }
        previewImageView.image = createImage(for: sampleImage)
    }
    
    func createImage(for image: SampleImage) -> UIImage? {
        let focus = CGFloat(depthSlider.value)
        return depthFilters.createSpotlightImage(for: image, withFocus: focus)
    }
}

extension ImagePreviewViewController {
    @objc func sliderValueChanged(_ sender: UISlider) {
        updateView()
    }
}


class ColorCollectionViewCell: UICollectionViewCell {
    
    static var reuseIdentifier: String = "ColorCell"
    
    public static func register(in collectionView: UICollectionView) {
        collectionView.register(self, forCellWithReuseIdentifier: reuseIdentifier)
    }
    
    func configure(with color: UIColor) {
        contentView.backgroundColor = color
        contentView.layer.borderWidth = 5
        contentView.layer.borderColor = UIColor.gray.cgColor
        contentView.layer.cornerRadius = 10.0
    }
}

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

