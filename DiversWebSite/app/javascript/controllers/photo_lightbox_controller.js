import { Controller } from "@hotwired/stimulus"

const MIN_SCALE = 1
const MAX_SCALE = 5

export default class extends Controller {
  static targets = ["overlay", "viewport", "image", "title", "caption", "counter", "scaleLabel"]
  static values = { photos: Array }

  connect() {
    this.onKeydown = this.onKeydown.bind(this)
    this.onMouseMove = this.onMouseMove.bind(this)
    this.onMouseUp = this.onMouseUp.bind(this)
    this.resetTransform()
  }

  disconnect() {
    this.removeDocumentListeners()
    document.removeEventListener("keydown", this.onKeydown)
  }

  open(event) {
    event.preventDefault()
    const index = Number(event.params.index)
    this.render(index)
    this.overlayTarget.classList.add("visible")
    document.body.classList.add("lightbox-open")
    document.addEventListener("keydown", this.onKeydown)
  }

  close(event) {
    event?.preventDefault()
    this.resetTransform()
    this.overlayTarget.classList.remove("visible")
    document.body.classList.remove("lightbox-open")
    document.removeEventListener("keydown", this.onKeydown)
    this.removeDocumentListeners()
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget && this.scale <= 1) this.close()
  }

  prev(event) {
    event?.preventDefault()
    if (this.photosValue.length < 2) return
    this.render((this.currentIndex - 1 + this.photosValue.length) % this.photosValue.length)
  }

  next(event) {
    event?.preventDefault()
    if (this.photosValue.length < 2) return
    this.render((this.currentIndex + 1) % this.photosValue.length)
  }

  zoomIn(event) {
    event?.preventDefault()
    event?.stopPropagation()
    const rect = this.viewportTarget.getBoundingClientRect()
    this.zoomAt(rect.left + rect.width / 2, rect.top + rect.height / 2, 1.25)
  }

  zoomOut(event) {
    event?.preventDefault()
    event?.stopPropagation()
    const rect = this.viewportTarget.getBoundingClientRect()
    this.zoomAt(rect.left + rect.width / 2, rect.top + rect.height / 2, 0.8)
  }

  resetZoom(event) {
    event?.preventDefault()
    event?.stopPropagation()
    this.resetTransform()
  }

  wheel(event) {
    event.preventDefault()
    event.stopPropagation()
    const factor = event.deltaY < 0 ? 1.12 : 0.88
    this.zoomAt(event.clientX, event.clientY, factor)
  }

  toggleZoom(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.scale > 1) {
      this.resetTransform()
      return
    }
    this.zoomAt(event.clientX, event.clientY, 2.5)
  }

  startPan(event) {
    if (this.scale <= 1 || event.button !== 0) return
    event.preventDefault()
    this.panning = true
    this.panMoved = false
    this.panStartX = event.clientX - this.translateX
    this.panStartY = event.clientY - this.translateY
    this.imageTarget.classList.add("is-dragging")
    document.addEventListener("mousemove", this.onMouseMove)
    document.addEventListener("mouseup", this.onMouseUp)
  }

  onMouseMove(event) {
    if (!this.panning) return
    this.panMoved = true
    this.translateX = event.clientX - this.panStartX
    this.translateY = event.clientY - this.panStartY
    this.applyTransform()
  }

  onMouseUp() {
    if (!this.panning) return
    this.panning = false
    this.imageTarget.classList.remove("is-dragging")
    this.removeDocumentListeners()
  }

  touchStart(event) {
    if (event.touches.length === 2) {
      event.preventDefault()
      this.pinchStartDistance = this.touchDistance(event.touches)
      this.pinchStartScale = this.scale
    } else if (event.touches.length === 1 && this.scale > 1) {
      this.panning = true
      this.panStartX = event.touches[0].clientX - this.translateX
      this.panStartY = event.touches[0].clientY - this.translateY
    }
  }

  touchMove(event) {
    if (event.touches.length === 2 && this.pinchStartDistance) {
      event.preventDefault()
      const distance = this.touchDistance(event.touches)
      const center = this.touchCenter(event.touches)
      const nextScale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, this.pinchStartScale * (distance / this.pinchStartDistance)))
      this.setScaleAt(center.x, center.y, nextScale)
    } else if (event.touches.length === 1 && this.panning) {
      event.preventDefault()
      this.translateX = event.touches[0].clientX - this.panStartX
      this.translateY = event.touches[0].clientY - this.panStartY
      this.applyTransform()
    }
  }

  touchEnd() {
    this.panning = false
    this.pinchStartDistance = null
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
    if (this.scale > 1) return
    if (event.key === "ArrowLeft") this.prev()
    if (event.key === "ArrowRight") this.next()
  }

  render(index) {
    this.currentIndex = index
    const photo = this.photosValue[index]
    if (!photo) return

    this.resetTransform()
    this.imageTarget.src = photo.url
    this.imageTarget.alt = photo.title
    this.titleTarget.textContent = photo.title
    this.captionTarget.textContent = photo.caption || ""
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${index + 1} / ${this.photosValue.length}`
    }
  }

  zoomAt(clientX, clientY, factor) {
    const nextScale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, this.scale * factor))
    this.setScaleAt(clientX, clientY, nextScale)
  }

  setScaleAt(clientX, clientY, nextScale) {
    const rect = this.viewportTarget.getBoundingClientRect()
    const pointerX = clientX - rect.left - rect.width / 2
    const pointerY = clientY - rect.top - rect.height / 2
    const imageX = (pointerX - this.translateX) / this.scale
    const imageY = (pointerY - this.translateY) / this.scale

    this.scale = nextScale
    this.translateX = pointerX - imageX * this.scale
    this.translateY = pointerY - imageY * this.scale
    this.applyTransform()
  }

  resetTransform() {
    this.scale = 1
    this.translateX = 0
    this.translateY = 0
    this.panning = false
    this.pinchStartDistance = null
    this.applyTransform()
  }

  applyTransform() {
    this.imageTarget.style.transform = `translate(${this.translateX}px, ${this.translateY}px) scale(${this.scale})`
    this.viewportTarget.classList.toggle("is-zoomed", this.scale > 1)
    this.imageTarget.style.cursor = this.scale > 1 ? "grab" : "zoom-in"
    if (this.hasScaleLabelTarget) {
      this.scaleLabelTarget.textContent = `${Math.round(this.scale * 100)}%`
    }
  }

  touchDistance(touches) {
    const dx = touches[0].clientX - touches[1].clientX
    const dy = touches[0].clientY - touches[1].clientY
    return Math.hypot(dx, dy)
  }

  touchCenter(touches) {
    return {
      x: (touches[0].clientX + touches[1].clientX) / 2,
      y: (touches[0].clientY + touches[1].clientY) / 2
    }
  }

  removeDocumentListeners() {
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
  }
}
