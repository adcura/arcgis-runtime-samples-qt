// [WriteFile Name=OfflineGeocode, Category=Search]
// [Legal]
// Copyright 2016 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// [Legal]

import QtQuick 2.6
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import Esri.ArcGISExtras 1.1
import Esri.ArcGISRuntime 100.0
import Esri.ArcGISRuntime.Toolkit.Controls 2.0

Rectangle {
    clip: true

    width: 800
    height: 600

    property real scaleFactor: System.displayScaleFactor
    property url dataPath: System.userHomePath + "/ArcGIS/Runtime/Data"

    property Point pinLocation: null
    property Point clickedPoint: null
    property bool isReverseGeocode: false
    property bool isPressAndHold: false

    // Map view UI presentation at top
    MapView {
        id: mapView
        anchors.fill: parent

        // initialize callout
        calloutData {
            title: "Address"
        }

        Map {

            // create local tiled layer using tile package
            Basemap {
                ArcGISTiledLayer {
                    TileCache {
                        path: dataPath + "/tpk/streetmap_SD.tpk"
                    }
                }
            }

            // set initial viewpoint
            ViewpointCenter {
                Point {
                    x: -13042254.715252
                    y: 3857970.236806
                    spatialReference: SpatialReference {
                        wkid: 3857
                    }
                }
                scale: 2e4
            }
        }

        // add a graphics overlay to the mapview
        GraphicsOverlay {
            id: graphicsOverlay

            // pin graphic that will visually display geocoding results
            Graphic {
                id: pinGraphic
                geometry: pinLocation
                visible: true

                PictureMarkerSymbol {
                    id: pictureMarker
                    height: 36 * scaleFactor
                    width: 19 * scaleFactor
                    url: "qrc:/Samples/Search/OfflineGeocode/red_pin.png"
                    offsetY: height / 2
                }
            }
        }

        Callout {
            id: callout
            calloutData: parent.calloutData
            screenOffsety: -19 * scaleFactor
        }

        // dismiss suggestions and no results notification on mouse press
        onMousePressed: {
            noResultsRect.visible = false;
            suggestionRect.visible = false;
        }

        onMouseClicked: {
            clickedPoint = mouse.mapPoint;
            mapView.identifyGraphicsOverlayWithMaxResults(graphicsOverlay, mouse.x, mouse.y, 5, 1);
        }

        onIdentifyGraphicsOverlayStatusChanged: {
            if (identifyGraphicsOverlayStatus === Enums.TaskStatusCompleted){

                // if clicked on the pin graphic, display callout.
                if (identifyGraphicsOverlayResults.length > 0)
                    callout.showCallout();

                // otherwise, normal reverse geocode
                else if (locatorTask.geocodeStatus !== Enums.TaskStatusInProgress){
                    isReverseGeocode = true;
                    locatorTask.reverseGeocodeWithParameters(clickedPoint, reverseGeocodeParams);
                }
            }
        }

        // hide suggestion window if viewpoint changes
        onViewpointChanged: {
            suggestionRect.visible = false;
            noResultsRect.visible = false;
        }

        // When user press and holds, prepare for real-time reverse geocoding
        onMousePressAndHold: {
            isPressAndHold = true;
            isReverseGeocode = true;

            if (locatorTask.geocodeStatus !== Enums.TaskStatusInProgress)
                locatorTask.reverseGeocodeWithParameters(mouse.mapPoint, reverseGeocodeParams);
        }

        // real-time reverse geocode if mouse being held down
        onMousePositionChanged: {
            if (isPressAndHold && locatorTask.geocodeStatus !== Enums.TaskStatusInProgress)
                locatorTask.reverseGeocodeWithParameters(mouse.mapPoint, reverseGeocodeParams);
        }

        // stop real-time reverse geocoding
        onMouseReleased: {
            isPressAndHold = false;
            isReverseGeocode = false;
        }
    }

    LocatorTask {
        id: locatorTask
        url: dataPath + "/Locators/SanDiegoStreetAddress/SanDiego_StreetAddress.loc"
        suggestions {
            // suggestions will update whenever textField's text property changes
            searchText: textField.text
            suggestTimerThreshold: 250
            suggestParameters: SuggestParameters {
                maxResults: 5
            }
        }

        GeocodeParameters {
            id: geocodeParams
            resultAttributeNames: ["Match_addr"]
            minScore: 75
            maxResults: 1
        }

        ReverseGeocodeParameters {
            id: reverseGeocodeParams
            maxDistance: 1000
            maxResults: 1
        }

        onGeocodeStatusChanged: {
            if (geocodeStatus === Enums.TaskStatusCompleted) {

                if(geocodeResults.length > 0) {
                    callout.dismiss();

                    // zoom to geocoded location
                    mapView.setViewpointGeometry(geocodeResults[0].extent)

                    // set pin and edit callout
                    pinLocation = geocodeResults[0].displayLocation;
                    mapView.calloutData.geoElement = pinGraphic;
                    mapView.calloutData.detail = geocodeResults[0].label;

                    // if it was a reverse geocode, also display callout
                    if (isReverseGeocode)
                        callout.showCallout();

                    // continue reverse geocoding if press and holding mouse
                    if (!isPressAndHold)
                        isReverseGeocode = false;
                }

                // if no result found, inform user
                else {
                    callout.dismiss()
                    noResultsRect.visible = true;
                    pinLocation = null;
                }
            }
        }
    }

    Column {
        anchors {
            fill: parent
            margins: 10 * scaleFactor
        }

        Rectangle {
            id: addressSearchRect
            width: 350 * scaleFactor
            height: 35 * scaleFactor
            color: "#f7f8fa"
            border {
                color: "#7B7C7D"
                width: 1 * scaleFactor
            }
            radius: 2

            Row {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                leftPadding: 5 * scaleFactor

                // search bar for geocoding
                TextField {
                    id: textField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.90
                    height: parent.height * 0.90
                    opacity: 0.95
                    placeholderText: "Enter an Address"
                    font.pixelSize: 14 * scaleFactor

                    style: TextFieldStyle {
                        background: Rectangle {
                            color: "#f7f8fa"
                            radius: 2
                        }
                    }

                    // when user types, make suggestions visible
                    onTextChanged: {
                        suggestionRect.visible = true;
                    }

                    // when enter or return is presed, begin geocoding with inputted text
                    onAccepted: {
                        suggestionRect.visible = false;
                        if (locatorTask.geocodeStatus !== Enums.TaskStatusInProgress)
                            locatorTask.geocodeWithParameters(text, geocodeParams);
                    }

                    // initial text
                    Component.onCompleted: {
                        text = "910 N Harbor Dr, San Diego, CA 92101";
                        suggestionRect.visible = false;
                    }
                }

                // button to open and close suggestions
                Rectangle {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        right: parent.right
                        margins: 5 * scaleFactor
                    }

                    width: 35 * scaleFactor
                    color: "#f7f8fa"
                    radius: 2

                    Image {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.width
                        source: suggestionRect.visible ? "qrc:/Samples/Search/OfflineGeocode/ic_menu_closeclear_light_d.png" : "qrc:/Samples/Search/OfflineGeocode/ic_menu_collapsedencircled_light_d.png"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                suggestionRect.visible = !suggestionRect.visible;
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: suggestionRect
            width: addressSearchRect.width
            height: 20 * locatorTask.suggestions.count * scaleFactor
            color: "#f7f8fa"
            opacity: 0.85

            ListView {
                id: suggestView
                model: locatorTask.suggestions
                height: parent.height
                delegate: Component {

                    Rectangle {
                        width: addressSearchRect.width
                        height: 20 * scaleFactor
                        color: "#f7f8fa"
                        border.color: "darkgray"

                        Text {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                leftMargin: 5 * scaleFactor
                                rightMargin: 5 * scaleFactor
                            }

                            font {
                                weight: Font.Black
                                pixelSize: 12 * scaleFactor
                            }

                            width: parent.width
                            text: label
                            elide: Text.ElideRight
                            leftPadding: 5 * scaleFactor
                            renderType: Text.NativeRendering
                            color: "black"
                        }

                        // when user clicks suggestion, geocode with the selected address
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (locatorTask.geocodeStatus !== Enums.TaskStatusInProgress) {
                                    // geocode with the suggestion
                                    locatorTask.geocodeWithParameters(label, geocodeParams);

                                    // change the text label
                                    textField.text = label;
                                }

                                // dismiss suggestions
                                suggestionRect.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // running when geocoding in progress
    BusyIndicator {
        id: busyIndicator
        anchors.centerIn: parent
        running: locatorTask.geocodeStatus === Enums.TaskStatusInProgress
    }

    Rectangle {
        id: noResultsRect
        anchors.centerIn: parent
        height: 50 * scaleFactor
        width: 200 * scaleFactor
        color: "#f7f8fa"
        visible: false
        radius: 2
        opacity: 0.85
        border.color: "black"

        Text {
            anchors.centerIn: parent
            text: "No matching address"
            renderType: Text.NativeRendering
            font.pixelSize: 18 * scaleFactor
        }
    }

    // Neatline rectangle
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border {
            width: 0.5 * scaleFactor
            color: "black"
        }
    }
}