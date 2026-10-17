var NappDrawerModule = require('dk.napp.drawer');
var TiBottomSheetControllerModule = require('ti.bottomsheetcontroller');

var bottomSheetController;

function createAPIExampleWindow() {
	var win = Ti.UI.createWindow();

	var data = [
		{
			title: 'Toggle shadow'
		},
		{
			title: 'Toggle stretch drawer'
		},
		{
			title: 'Close Drawer'
		},
		{
			title: 'New Window'
		},
		{
			title: 'Default Window'
		},
		{
			title: 'Remove right Drawer'
		},
		{
			title: 'Toggle full-width drawer'
		}
	];

	var tableView = Ti.UI.createTableView({
		data: data
	});

	tableView.addEventListener('click', function (e) {
		Ti.API.info('isLeftWindowOpen: ' + drawer.isLeftWindowOpen());
		switch (e.index) {
			case 0:
				drawer.showShadow = !drawer.showShadow;
				break;
			case 1:
				drawer.shouldStretchDrawer = !drawer.shouldStretchDrawer;
				break;
			case 2:
				drawer.toggleLeftWindow();
				break;
			case 3:
				var newWin = openNewNavWindow();
				drawer.centerWindow = newWin;
				drawer.toggleLeftWindow();
				break;
			case 4:
				drawer.centerWindow = createCenterNavWindow();
				drawer.toggleLeftWindow();
				break;
			case 5:
				drawer.rightWindow = false;
				drawer.toggleLeftWindow();
				break;
			case 6:
				win.drawerExpanded = !win.drawerExpanded;
				drawer.setLeftDrawerWidth({
					width: win.drawerExpanded ? drawer.rect.width : 200,
					animated: true
				});
				break;
		}
	});

	win.add(tableView);
	return win;
}

function openNewNavWindow() {
	var leftBtn = Ti.UI.createButton({
		title: 'Left'
	});
	leftBtn.addEventListener('click', function () {
		drawer.toggleLeftWindow();
	});
	var win = Ti.UI.createWindow({
		backgroundColor: '#222',
		translucent: true,
		extendEdges: [Ti.UI.EXTEND_EDGE_TOP],
		title: 'New Nav Window',
		barColor: '#FFA',
		tintColor: 'yellow',
		leftNavButton: leftBtn
	});

	var scrollView = Ti.UI.createScrollView({
		layout: 'vertical',
		left: 0,
		right: 0,
		contentHeight: 'auto',
		contentWidth: '100%',
		showVerticalScrollIndicator: true,
		showHorizontalScrollIndicator: false
	});

	for (var i = 0; i < 20; i++) {
		var label = Ti.UI.createLabel({
			top: 30,
			text: 'iOS7 is the new black',
			color: '#FFF',
			font: {
				fontSize: 20
			}
		});
		scrollView.add(label);
	}
	win.add(scrollView);
	var navController = Ti.UI.createNavigationWindow({
		window: win
	});
	return navController;
}

function createCenterNavWindow() {
	var leftBtn = Ti.UI.createButton({
		title: 'Left'
	});
	leftBtn.addEventListener('click', function () {
		drawer.toggleLeftWindow();
	});
	var rightBtn = Ti.UI.createButton({
		title: 'Right'
	});
	rightBtn.addEventListener('click', function () {
		drawer.toggleRightWindow();
	});

	var win = Ti.UI.createWindow({
		backgroundColor: '#eee',
		translucent: false,
		title: 'NappDrawer',
		barColor: '#ca2127',
		tintColor: '#ca2127',
		navTintColor: '#fff',
		titleAttributes: {
			color: '#fff'
		},
		leftNavButton: leftBtn,
		rightNavButton: rightBtn
	});

	var closeGestureMode = 1;
	var closeGestureModeBtn = Ti.UI.createButton({
		title: 'closeGestureMode: ALL',
		width: 300,
		top: 80
	});

	closeGestureModeBtn.addEventListener('click', function (e) {
		if (closeGestureMode == 2) {
			closeGestureMode = 0;
		} else {
			closeGestureMode++;
		}
		switch (closeGestureMode) {
			case 0:
				drawer.closeDrawerGestureMode = NappDrawerModule.CLOSE_MODE_TAP_CENTERWINDOW;
				closeGestureModeBtn.title = 'closeGesture: Tap Center';
				break;
			case 1:
				drawer.closeDrawerGestureMode = NappDrawerModule.CLOSE_MODE_ALL;
				closeGestureModeBtn.title = 'closeGesture: ALL';
				break;
			case 2:
				drawer.closeDrawerGestureMode = NappDrawerModule.CLOSE_MODE_PANNING_NAVBAR;
				closeGestureModeBtn.title = 'closeGesture: NAVBAR';
				break;
		}
	});
	win.add(closeGestureModeBtn);

	var animationMode = 0;
	var animationModeBtn = Ti.UI.createButton({
		title: 'animation: Cycle shared mode',
		width: 300,
		top: 140
	});
	animationModeBtn.addEventListener('click', function (e) {
		// Clear the independent startup modes before cycling the shared mode.
		drawer.leftAnimationMode = null;
		drawer.rightAnimationMode = null;
		if (animationMode == 5) {
			animationMode = 0;
		} else {
			animationMode++;
		}
		switch (animationMode) {
			case 0:
				drawer.animationMode = NappDrawerModule.ANIMATION_NONE;
				animationModeBtn.title = 'animation: None';
				break;
			case 1:
				drawer.animationMode = NappDrawerModule.ANIMATION_PARALLAX_FACTOR_3;
				animationModeBtn.title = 'animation: Parallax factor 3';
				break;
			case 2:
				drawer.animationMode = NappDrawerModule.ANIMATION_PARALLAX_FACTOR_7;
				animationModeBtn.title = 'animation: Parallax factor 7';
				break;
			case 3:
				drawer.animationMode = NappDrawerModule.ANIMATION_FADE;
				animationModeBtn.title = 'animation: Fade';
				break;
			case 4:
				drawer.animationMode = NappDrawerModule.ANIMATION_SLIDE;
				animationModeBtn.title = 'animation: Slide';
				break;
			case 5:
				drawer.animationMode = NappDrawerModule.ANIMATION_SLIDE_SCALE;
				animationModeBtn.title = 'animation: Slide & Scale';
				break;
		}
	});
	win.add(animationModeBtn);

	var bottomSheetBtn = Ti.UI.createButton({
		title: 'Open Native Bottom Sheet',
		width: 300,
		top: 200
	});
	bottomSheetBtn.addEventListener('click', function () {
		openBottomSheet();
	});
	win.add(bottomSheetBtn);

	var slider = Ti.UI.createSlider({
		top: 280,
		min: 50,
		max: 280,
		width: 280,
		value: 200
	});
	var label = Ti.UI.createLabel({
		text: 'Left Drawer Width: ' + slider.value,
		top: 250
	});
	slider.addEventListener('touchend', function (e) {
		var value = Math.round(e.value);
		label.text = 'Left Drawer Width: ' + value;
		drawer.leftDrawerWidth = value;
	});
	win.add(label);
	win.add(slider);

	var navController = Ti.UI.createNavigationWindow({
		window: win
	});
	return navController;
}

function openBottomSheet() {
	if (bottomSheetController) {
		return;
	}

	var content = Ti.UI.createView({
		backgroundColor: '#f4f5f8'
	});

	content.add(
		Ti.UI.createLabel({
			text: 'Native UISheetPresentationController',
			color: '#18212f',
			top: 30,
			font: {
				fontSize: 21,
				fontWeight: 'bold'
			}
		})
	);

	content.add(
		Ti.UI.createLabel({
			text: 'Use these controls while the sheet is visible.',
			color: '#4d5664',
			top: 70
		})
	);

	var leftDrawerBtn = Ti.UI.createButton({
		title: 'Left',
		left: 12,
		top: 110,
		width: 80
	});
	leftDrawerBtn.addEventListener('click', function () {
		drawer.toggleLeftWindow();
	});
	content.add(leftDrawerBtn);

	var rightDrawerBtn = Ti.UI.createButton({
		title: 'Right',
		left: 100,
		top: 110,
		width: 80
	});
	rightDrawerBtn.addEventListener('click', function () {
		drawer.toggleRightWindow();
	});
	content.add(rightDrawerBtn);

	var mediumDetentBtn = Ti.UI.createButton({
		title: 'Medium',
		right: 100,
		top: 110,
		width: 86
	});
	mediumDetentBtn.addEventListener('click', function () {
		bottomSheetController.changeCurrentDetent('medium');
	});
	content.add(mediumDetentBtn);

	var closeSheetBtn = Ti.UI.createButton({
		title: 'Close',
		right: 12,
		top: 110,
		width: 80
	});
	closeSheetBtn.addEventListener('click', function () {
		bottomSheetController.close({animated: true});
	});
	content.add(closeSheetBtn);

	bottomSheetController = TiBottomSheetControllerModule.createBottomSheet({
		contentView: content,
		detents: [
			{
				identifier: 'bar',
				height: 190
			},
			'medium',
			'large'
		],
		startDetent: 'bar',
		largestUndimmedDetentIdentifier: 'bar',
		dismissible: false,
		prefersGrabberVisible: true
	});

	bottomSheetController.addEventListener('open', function () {
		drawer.attachPresentedSheet();
		Ti.API.info('isAnySheetOpen after open: ' + drawer.isAnySheetOpen());
	});

	bottomSheetController.addEventListener('close', function () {
		drawer.detachPresentedSheet();
		bottomSheetController = null;
		Ti.API.info('isAnySheetOpen after close: ' + drawer.isAnySheetOpen());
	});

	bottomSheetController.open();
}

var mainWindow = createCenterNavWindow();

var drawer = NappDrawerModule.createDrawer({
	leftWindow: createAPIExampleWindow(),
	centerWindow: mainWindow,
  initialDrawerSide: 'left', // 'center' preserves the original closed startup; 'right' starts on the other side.
	rightWindow: Ti.UI.createWindow({
		backgroundColor: '#FFF'
	}),
	closeDrawerGestureMode: NappDrawerModule.CLOSE_MODE_ALL,
	closeDrawerBezelWidth: 40, // Points; applies to CLOSE_MODE_BEZEL_PANNING_CENTERWINDOW, not CLOSE_MODE_ALL.
	openDrawerGestureMode: NappDrawerModule.OPEN_MODE_ALL,
	openDrawerBezelWidth: 40, // Points; applies when using OPEN_MODE_BEZEL_PANNING_CENTERWINDOW, not OPEN_MODE_ALL.
	hapticFeedback: 'gesture', // Set to 'all' to include code/button-driven transitions.
	hapticStyle: 'light',
	animationMode: NappDrawerModule.ANIMATION_SLIDE,
	leftAnimationMode: NappDrawerModule.ANIMATION_PARALLAX_FACTOR_7,
	rightAnimationMode: NappDrawerModule.ANIMATION_SLIDE,
	followsPresentedSheet: true,
	presentedSheetEdgeWidth: 32, // Set to 0 to disable sheet-edge opening.
	rootBackgroundColor: '#eee', // Background behind rounded center-window corners.
	centerCornerMode: 'concentric', // Use 'continuous' for an explicit squircle-style radius.
	centerCornerRadius: 32, // Also the concentric fallback on iOS 18–25.
	centerBorderWidth: 1,
	centerBorderColor: '#888',
	centerBorderOpacity: 0.8,
	centerBorderFollowsSliding: true, // Native fade: closed = hidden, open = visible.
	showShadow: false, // Use the example's Toggle shadow row to enable it.
	shadowRadius: 10,
	shadowColor: '#000000',
	shadowOpacity: 0.8,
	leftDrawerWidth: 200,
	rightDrawerWidth: 120,
	statusBarStyle: NappDrawerModule.STATUSBAR_WHITE, // remember to set UIViewControllerBasedStatusBarAppearance to false in tiapp.xml
	orientationModes: [Ti.UI.PORTRAIT, Ti.UI.UPSIDE_PORTRAIT]
});

drawer.addEventListener('centerWindowDidFocus', function () {
	Ti.API.info('Center did focus!');
});

drawer.addEventListener('centerWindowDidBlur', function () {
	Ti.API.info('Center did blur!');
});

drawer.addEventListener('windowDidOpen', function (e) {
	Ti.API.info('windowDidOpen');
});

drawer.addEventListener('windowDidClose', function (e) {
	Ti.API.info('windowDidClose');
});

drawer.addEventListener('open', function () {
	Ti.API.info('Resolved center corner radius: ' + drawer.getCenterCornerRadius() + 'pt');
});
drawer.open();

drawer.addEventListener('sliding', function (e) {
	if (e.resizing) {
		Ti.API.info('Resize: width=' + e.drawerWidth + 'pt, centerOffset=' + e.centerOffset + 'pt, progress=' + e.progress);
	}
});

drawer.addEventListener('drawerTransition', function (e) {
	Ti.API.info('Drawer transition: ' + e.state + ', side=' + e.side + ', source=' + e.source);
});

// Open the sheet after the drawer window is ready, matching the runtime test.
setTimeout(openBottomSheet, 800);

Ti.API.info('isAnyWindowOpen: ' + drawer.isAnyWindowOpen());
