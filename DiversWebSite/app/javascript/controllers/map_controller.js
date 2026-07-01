import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "canvas", "filters", "counter", "popup", "popupTitle", "popupBody",
    "popupLink", "favoriteBtn", "favoriteLabel"
  ]

  static values = {
    reportsUrl: String,
    csrfToken: String,
    loggedIn: Boolean
  }

  connect() {
    this.selectedReport = null
    this.reports = []
    const params = new URLSearchParams(window.location.search)
    const favoritesOnly = this.filtersTarget.querySelector('[name=favorites_only]')
    if (params.get("favorites_only") === "1" && favoritesOnly) {
      favoritesOnly.checked = true
    }
    const reportIdInput = this.filtersTarget.querySelector('[name=report_id]')
    const reportId = params.get("report_id")
    if (reportId && reportIdInput) {
      reportIdInput.value = reportId
    }
    this.initMap()
    this.loadReports()
  }

  initMap() {
    const region = { minLon: 27.0, minLat: 41.0, maxLon: 42.5, maxLat: 47.8 }
    const extent = ol.proj.transformExtent(
      [region.minLon, region.minLat, region.maxLon, region.maxLat],
      "EPSG:4326",
      "EPSG:3857"
    )

    this.source = new ol.source.Vector()
    this.layer = new ol.layer.Vector({
      source: this.source,
      style: (feature) => {
        const favorited = feature.get("favorited")
        return new ol.style.Style({
          image: new ol.style.Circle({
            radius: favorited ? 8 : 6,
            fill: new ol.style.Fill({ color: favorited ? "#f39c12" : "#e74c3c" }),
            stroke: new ol.style.Stroke({ color: "#ffffff", width: 2 })
          })
        })
      }
    })

    this.map = new ol.Map({
      target: this.canvasTarget,
      layers: [
        new ol.layer.Tile({
          source: new ol.source.XYZ({
            url: "https://{a-d}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
            attributions: "&copy; OpenStreetMap &copy; CARTO"
          })
        }),
        this.layer
      ],
      view: new ol.View({
        center: ol.proj.fromLonLat([34.1, 45.0]),
        zoom: 7,
        minZoom: 5,
        maxZoom: 16
      })
    })

    this.map.getView().fit(extent, { padding: [40, 40, 40, 40] })

    this.map.on("click", (event) => {
      const feature = this.map.forEachFeatureAtPixel(event.pixel, (f) => f)
      if (feature) {
        this.showPopup(feature.get("report"))
      }
    })
  }

  async loadReports() {
    const params = new URLSearchParams(new FormData(this.filtersTarget))
    const url = `${this.reportsUrlValue}?${params.toString()}`

    this.counterTarget.textContent = "Загрузка точек..."
    const response = await fetch(url, { headers: { Accept: "application/json" } })
    this.reports = await response.json()
    this.renderMarkers()
    this.counterTarget.textContent = `На карте: ${this.reports.length} точек`
    this.focusReportIfNeeded()
  }

  focusReportIfNeeded() {
    const params = new URLSearchParams(window.location.search)
    const formReportId = this.filtersTarget.querySelector('[name=report_id]')?.value
    const reportId = params.get("report_id") || formReportId
    if (!reportId || this.reports.length === 0) return

    const report = this.reports.find((r) => String(r.id) === String(reportId))
    if (!report) return

    this.showPopup(report)
    this.map.getView().animate({
      center: ol.proj.fromLonLat([report.longitude, report.latitude]),
      zoom: 12,
      duration: 500
    })
  }

  renderMarkers() {
    const selectedId = this.selectedReport?.id
    this.source.clear()
    this.reports.forEach((report) => {
      const feature = new ol.Feature({
        geometry: new ol.geom.Point(ol.proj.fromLonLat([report.longitude, report.latitude])),
        report: report
      })
      feature.set("favorited", report.favorited)
      this.source.addFeature(feature)
    })

    if (selectedId) {
      const updated = this.reports.find((r) => r.id === selectedId)
      if (updated) this.showPopup(updated)
    }
  }

  applyFilters(event) {
    if (event) event.preventDefault()
    this.loadReports()
  }

  resetFilters() {
    this.filtersTarget.reset()
    this.loadReports()
  }

  showPopup(report) {
    this.selectedReport = report
    this.popupTitleTarget.textContent = `Отчёт #${report.id}`
    this.popupBodyTarget.innerHTML = `
      <div><strong>Дата:</strong> ${report.observation_date}</div>
      <div><strong>Встреча:</strong> ${report.encounter_type}</div>
      <div><strong>Глубина:</strong> ${report.depth_label}</div>
      <div><strong>Субстрат:</strong> ${report.substrate_type}</div>
      <div><strong>Фото:</strong> ${report.photos_count}</div>
    `
    this.popupLinkTarget.href = report.show_url
    this.updateFavoriteButton(report.favorited)
    this.popupTarget.classList.add("visible")
  }

  closePopup() {
    this.selectedReport = null
    this.popupTarget.classList.remove("visible")
  }

  updateFavoriteButton(favorited) {
    this.favoriteBtnTarget.classList.toggle("btn-warning", favorited)
    this.favoriteBtnTarget.classList.toggle("btn-outline-warning", !favorited)
    this.favoriteLabelTarget.textContent = favorited ? "В избранном" : "В избранное"
  }

  async toggleFavorite() {
    if (!this.selectedReport) return

    const report = this.selectedReport
    const method = report.favorited ? "DELETE" : "POST"
    const url = `/favorites/${report.id}`

    const response = await fetch(url, {
      method,
      headers: {
        "X-CSRF-Token": this.csrfTokenValue,
        Accept: "application/json"
      }
    })

    if (response.ok) {
      report.favorited = !report.favorited
      this.updateFavoriteButton(report.favorited)
      this.renderMarkers()
    }
  }
}
