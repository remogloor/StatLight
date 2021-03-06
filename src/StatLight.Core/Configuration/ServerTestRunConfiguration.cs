﻿using System;
using StatLight.Core.WebServer.XapHost;

namespace StatLight.Core.Configuration
{
    public class ServerTestRunConfiguration
    {
        public ServerTestRunConfiguration(Func<byte[]> xapHost, string xapToTest, XapHostType xapHostType, string queryString, bool forceBrowserStart, WindowGeometry windowGeometry, bool isPhoneRun)
        {
            if (xapHost == null) throw new ArgumentNullException("xapHost");
            if (xapToTest == null) throw new ArgumentNullException("xapToTest");

            HostXap = xapHost;
            XapToTestPath = xapToTest;
            XapHostType = xapHostType;
            QueryString = queryString;
            ForceBrowserStart = forceBrowserStart;
            WindowGeometry = windowGeometry;
            IsPhoneRun = isPhoneRun;
        }

        public Func<byte[]> HostXap { get; private set; }
        public string XapToTestPath { get; private set; }
        public XapHostType XapHostType { get; private set; }

        public string QueryString { get; private set; }

        public bool ForceBrowserStart { get; private set; }
        public WindowGeometry WindowGeometry { get; set; }
        public bool IsPhoneRun { get; private set; }
    }
}
