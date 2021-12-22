import MetalKit

struct Particle{
    var color: SIMD4<Float>
    var position: SIMD2<Float>
    var angle: Float
}

class MainView: MTKView {
    
    @IBOutlet weak var txtDotCount: NSTextField!
    @IBOutlet weak var sldDotCount: NSSlider!
    
    var commandQueue: MTLCommandQueue!
    var clearPass: MTLComputePipelineState!
    var drawDotPass: MTLComputePipelineState!
    var blurPass: MTLComputePipelineState!
    
    var particleBuffer: MTLBuffer!
    
    var screenSize: Float {
        return Float(self.bounds.width * 2)
    }
    
    var particleCount: Int = 1
    
    override func viewDidMoveToWindow() {
        txtDotCount.stringValue = String(particleCount)
        sldDotCount.floatValue = Float(particleCount)
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.framebufferOnly = false
        
        self.device = MTLCreateSystemDefaultDevice()
        
        self.commandQueue = device?.makeCommandQueue()
        
        let library = device?.makeDefaultLibrary()
        let clearFunc = library?.makeFunction(name: "clear_pass_func")
        let drawDotFunc = library?.makeFunction(name: "draw_dots_func")
        let blurFunc = library?.makeFunction(name: "blur_pass_func")
        
        do{
            clearPass = try device?.makeComputePipelineState(function: clearFunc!)
            drawDotPass = try device?.makeComputePipelineState(function: drawDotFunc!)
            blurPass = try device?.makeComputePipelineState(function: blurFunc!)
        }catch let error as NSError{
            print(error)
        }
        guard let drawable = self.currentDrawable else { return }
        createParticles(h: drawable.texture.height, w: drawable.texture.width)
    }
    
    func createParticles(h: Int, w: Int){
        var particles: [Particle] = []
        for _ in 0..<particleCount{
            let a = Float.random(in: 0...(3.1415*2))
            let c = Int.random(in: 0...1)
            var color = SIMD4<Float>(0 * Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1), 1)
            if c > 0 {
                color =  SIMD4<Float>(Float.random(in: 0...1), Float.random(in: 0...1), 0 * Float.random(in: 0.8...1), 1)
            }
            let particle = Particle(color: color,
                                    position: Float.random(in: 0...0*(Float(min(h, w)/2) - 1)) * SIMD2<Float>(cos(a), sin(a)) + SIMD2<Float>(Float(w)/2, Float(h)/2),
                                    angle: a +  0*Float.random(in: 0...3.1415) - 1 * 3.1415)
            particles.append(particle)
        }
        particleBuffer = device?.makeBuffer(bytes: particles, length: MemoryLayout<Particle>.stride * particleCount, options: .storageModeManaged)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = self.currentDrawable else { return }
        
        let commandbuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandbuffer?.makeComputeCommandEncoder()
        
        computeCommandEncoder?.setComputePipelineState(clearPass)
        computeCommandEncoder?.setTexture(drawable.texture, index: 0)
        
        let w = clearPass.threadExecutionWidth
        let h = clearPass.maxTotalThreadsPerThreadgroup / w
        
        var threadsPerThreadGroup = MTLSize(width: w, height: h, depth: 1)
        var threadsPerGrid = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        computeCommandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)

        computeCommandEncoder?.setComputePipelineState(drawDotPass)
        computeCommandEncoder?.setBuffer(particleBuffer, offset: 0, index: 0)
        threadsPerGrid = MTLSize(width: particleCount, height: 1, depth: 1)
        threadsPerThreadGroup = MTLSize(width: w, height: 1, depth: 1)
        computeCommandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)

//        computeCommandEncoder?.setComputePipelineState(blurPass)
//        computeCommandEncoder?.setTexture(drawable.texture, index: 0)
//        computeCommandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        computeCommandEncoder?.endEncoding()
        commandbuffer?.present(drawable)
        commandbuffer?.commit()
    }
    
    @IBAction func sldParticleCountUpdate(_ sender: NSSlider) {
        txtDotCount.stringValue = String(Int(sender.floatValue))
    }
    
    @IBAction func btnUpdate(_ sender: NSButton) {
        particleCount = Int(txtDotCount.stringValue)!
        sldDotCount.floatValue = Float(txtDotCount.stringValue)!
        guard let drawable = self.currentDrawable else { return }
        createParticles(h: drawable.texture.height, w: drawable.texture.width)
    }
    
}
