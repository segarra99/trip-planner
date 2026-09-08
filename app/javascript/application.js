import L from "leaflet";

document.addEventListener("DOMContentLoaded", () => {
    const form = document.querySelector("#planner-form");
    const originSelect = document.querySelector("#origin");
    const destinationSelect = document.querySelector("#destination");
    const categorySelect = document.querySelector("#category");
    const numberOfPoisInput = document.querySelector("#number-of-pois");
    const submitButton = form.querySelector("button[type='submit']");
    const poiPanel = document.querySelector("#poi-panel");

    let map;
    let markersLayer;
    let routeLayer;
    let locations = [];
    let poiMarkers = [];

    initializeMap();
    initialize();

    form.addEventListener("submit", handleSubmit);
    originSelect.addEventListener("change", updateLocationOptions);
    destinationSelect.addEventListener("change", updateLocationOptions);

    async function initialize() {
        setFormLoading(true);

        try {
            const [loadedLocations, categories] = await Promise.all([
                fetchAll("/locations", "locations"),
                fetchAll("/categories", "categories"),
            ]);

            locations = loadedLocations;

            populateLocations(originSelect);
            populateLocations(destinationSelect);
            updateLocationOptions();
            populateCategories(categories);
        } catch (error) {
            console.error("Failed to initialize planner:", error);
            showError("Unable to load the roadtrip data. Please try again.");
        } finally {
            setFormLoading(false);
        }
    }

    function initializeMap() {
        map = L.map("map").setView([39.5, -8.0], 7);

        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "&copy; OpenStreetMap contributors",
        }).addTo(map);

        markersLayer = L.layerGroup().addTo(map);
        routeLayer = L.layerGroup().addTo(map);
    }

    async function fetchAll(endpoint, collectionKey) {
        const results = [];
        let page = 1;
        let totalPages = 1;

        do {
            const params = new URLSearchParams({
                page,
                per_page: 100,
            });

            const response = await fetch(`${endpoint}?${params}`);

            if (!response.ok) {
                throw new Error(`${endpoint} returned ${response.status}`);
            }

            const data = await response.json();

            results.push(...data[collectionKey]);
            totalPages = data.pagination.total_pages;
            page += 1;
        } while (page <= totalPages);

        return results;
    }

    function populateLocations(select) {
        select.replaceChildren();

        locations.forEach((location) => {
            const option = document.createElement("option");

            option.value = location.id;
            option.textContent = location.name;

            select.appendChild(option);
        });
    }

    function populateCategories(categories) {
        categories.forEach((category) => {
            const option = document.createElement("option");

            option.value = category.id;
            option.textContent = capitalize(category.name);

            categorySelect.appendChild(option);
        });
    }

    async function handleSubmit(event) {
        event.preventDefault();
        clearError();

        const origin = getSelectedLocation(originSelect);
        const destination = getSelectedLocation(destinationSelect);
        const numberOfPois = Number(numberOfPoisInput.value);

        if (!origin || !destination) {
            showError("Please select an origin and destination.");
            return;
        }

        if (origin.id === destination.id) {
            showError("Origin and destination must be different.");
            return;
        }

        if (!Number.isInteger(numberOfPois) || numberOfPois < 1) {
            showError("Number of POIs must be a positive integer.");
            return;
        }

        const params = new URLSearchParams({
            origin: origin.id,
            destination: destination.id,
            number_of_pois: numberOfPois,
        });

        if (categorySelect.value) {
            params.set("category", categorySelect.value);
        }

        setFormLoading(true);

        try {
            const response = await fetch(`/trip-planning?${params}`);

            if (!response.ok) {
                const data = await response.json().catch(() => ({}));

                throw new Error(
                    data.error ||
                        `Request failed with status ${response.status}`,
                );
            }

            const pois = await response.json();

            await renderTrip(origin, destination, pois);
        } catch (error) {
            console.error("Failed to plan roadtrip:", error);
            showError(error.message || "Unable to plan the roadtrip.");
        } finally {
            setFormLoading(false);
        }
    }

    function getSelectedLocation(select) {
        return locations.find(
            (location) => String(location.id) === String(select.value),
        );
    }

    async function renderTrip(origin, destination, pois) {
        markersLayer.clearLayers();
        routeLayer.clearLayers();
        poiMarkers = [];

        renderPoiPanel(pois);

        addLocationMarker(origin, "Origin");

        pois.forEach((poi, index) => {
            poiMarkers.push(addPoiMarker(poi, index + 1));
        });

        addLocationMarker(destination, "Destination");

        const points = [origin, ...pois, destination];

        const route = await fetchRoute(points);

        L.geoJSON(route, {
            style: {
                weight: 5,
                opacity: 0.8,
            },
        }).addTo(routeLayer);

        const routeBounds = L.geoJSON(route).getBounds();

        map.fitBounds(routeBounds, {
            padding: [40, 40],
        });
    }

    async function fetchRoute(points) {
        const coordinates = points
            .map((point) => `${point.longitude},${point.latitude}`)
            .join(";");

        const url =
            `https://router.project-osrm.org/route/v1/driving/${coordinates}` +
            "?overview=full&geometries=geojson";

        const response = await fetch(url);

        if (!response.ok) {
            throw new Error("Unable to calculate the driving route.");
        }

        const data = await response.json();

        if (data.code !== "Ok" || !data.routes?.length) {
            throw new Error("No driving route could be found.");
        }

        return data.routes[0].geometry;
    }

    function renderPoiPanel(pois) {
        poiPanel.replaceChildren();

        const header = document.createElement("div");
        header.className = "poi-panel-header";

        const heading = document.createElement("h2");
        heading.textContent = "Points of interest";

        const subtitle = document.createElement("p");
        subtitle.className = "poi-panel-subtitle";
        subtitle.textContent = `${pois.length} stop${pois.length === 1 ? "" : "s"} on your route`;

        header.append(heading, subtitle);
        poiPanel.appendChild(header);

        if (pois.length === 0) {
            const emptyMessage = document.createElement("p");
            emptyMessage.className = "poi-panel-empty";
            emptyMessage.textContent = "No POIs were found for this trip.";
            poiPanel.appendChild(emptyMessage);
            return;
        }

        pois.forEach((poi, index) => {
            const card = document.createElement("article");
            card.className = "poi-card";
            card.dataset.number = index + 1;

            const title = document.createElement("h3");
            title.textContent = poi.name;

            const categories = document.createElement("p");
            categories.className = "poi-categories";

            const categoryNames = (poi.categories || []).map((category) =>
                capitalize(category.name),
            );

            categories.textContent = categoryNames.length
                ? categoryNames.join(", ")
                : "No category";

            const description = document.createElement("p");
            description.className = "poi-description";
            description.textContent =
                poi.description || "No description available.";

            card.append(title, categories, description);

            card.addEventListener("click", () => {
                const marker = poiMarkers[index];

                if (!marker) {
                    return;
                }

                map.setView(marker.getLatLng(), 12);
                marker.openPopup();
            });

            poiPanel.appendChild(card);
        });
    }

    function addLocationMarker(location, label) {
        const isOrigin = label === "Origin";

        const marker = L.marker([location.latitude, location.longitude], {
            title: location.name,
            icon: L.divIcon({
                className: "location-marker",
                html: `
                    <div class="location-marker-pin ${isOrigin ? "origin" : "destination"}">
                        <span></span>
                    </div>
                `,
                iconSize: [30, 42],
                iconAnchor: [15, 42],
                popupAnchor: [0, -42],
            }),
        });

        marker.bindPopup(`
            <strong>${escapeHtml(location.name)}</strong>
            <br>
            ${label}
        `);

        marker.addTo(markersLayer);
    }

    function addPoiMarker(poi, number) {
        const marker = L.marker([poi.latitude, poi.longitude], {
            title: poi.name,
            icon: L.divIcon({
                className: "poi-marker",
                html: `
                    <div class="poi-marker-pin">
                        <span>${number}</span>
                    </div>
                `,
                iconSize: [30, 42],
                iconAnchor: [15, 42],
                popupAnchor: [0, -42],
            }),
        });

        const categories = (poi.categories || [])
            .map((category) => capitalize(category.name))
            .join(", ");

        let popup = `<strong>${number}. ${escapeHtml(poi.name)}</strong>`;

        if (categories) {
            popup += `<br>${escapeHtml(categories)}`;
        }

        marker.bindPopup(popup);
        marker.addTo(markersLayer);

        return marker;
    }

    function setFormLoading(loading) {
        submitButton.disabled = loading;
        submitButton.textContent = loading ? "Planning..." : "Plan roadtrip";
    }

    function showError(message) {
        let errorElement = document.querySelector("#planner-error");

        if (!errorElement) {
            errorElement = document.createElement("div");
            errorElement.id = "planner-error";
            errorElement.setAttribute("role", "alert");
            form.insertAdjacentElement("afterend", errorElement);
        }

        errorElement.textContent = message;
    }

    function clearError() {
        document.querySelector("#planner-error")?.remove();
    }

    function escapeHtml(value) {
        const element = document.createElement("div");
        element.textContent = value ?? "";
        return element.innerHTML;
    }

    function capitalize(value) {
        if (!value) {
            return "";
        }

        return value.charAt(0).toUpperCase() + value.slice(1);
    }

    function updateLocationOptions() {
        const originId = originSelect.value;
        const destinationId = destinationSelect.value;

        Array.from(originSelect.options).forEach((option) => {
            option.disabled =
                option.value === destinationId && destinationId !== "";
        });

        Array.from(destinationSelect.options).forEach((option) => {
            option.disabled = option.value === originId && originId !== "";
        });
    }
});
