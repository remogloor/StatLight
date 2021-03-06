using System;
using System.Collections.Generic;
using System.ComponentModel.Composition.Hosting;
using System.IO;
using System.Linq;
using System.Reflection;
using StatLight.Core.Common;
using StatLight.Core.Events;

namespace StatLight.Core.Runners
{
    public class ExtensionResolver
    {
        private readonly ILogger _logger;
        private readonly IEventSubscriptionManager _eventSubscriptionManager;

        public ExtensionResolver(ILogger logger, IEventSubscriptionManager eventSubscriptionManager)
        {
            _logger = logger;
            _eventSubscriptionManager = eventSubscriptionManager;
        }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
        public void AddExtensionsToEventAggregator()
        {
            var extensions = GetExtensions().ToList();

            if (!extensions.Any())
                return;

            _logger.Debug("********** Extensions **********");
            foreach (var extensionInstance in extensions)
            {
                _logger.Debug("* Adding - {0}".FormatWith(extensionInstance.GetType().FullName));
                _eventSubscriptionManager.AddListener(extensionInstance);
            }
            _logger.Debug("********************************");
        }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Design", "CA1031:DoNotCatchGeneralExceptionTypes")]
        private IEnumerable<object> GetExtensions()
        {
            var testingReportEventsExtensions = new List<IShouldBeAddedToEventAggregator>();
            try
            {
                var path = GetFullPath("Extensions");
                if (!Directory.Exists(path))
                {
                    Directory.CreateDirectory(path);
                }

                using (var directoryCatalog = new DirectoryCatalog(path))
                using (var compositionContainer = new CompositionContainer(directoryCatalog))
                {
                    testingReportEventsExtensions = compositionContainer.GetExports<IShouldBeAddedToEventAggregator>().Select(s => s.Value).ToList();
                }
            }
            catch (ReflectionTypeLoadException rfex)
            {
                string loaderExceptionMessages = "";
                foreach (var t in rfex.LoaderExceptions)
                {
                    loaderExceptionMessages += "   -  ";
                    loaderExceptionMessages += t.Message;
                    loaderExceptionMessages += Environment.NewLine;
                }

                string msg =
                    @"
********************* ReflectionTypeLoadException *********************
***** Begin Loader Exception Messages *****
{0}
***** End Loader Exception Messages *****
"
                        .FormatWith(loaderExceptionMessages);

                _logger.Error(msg);
            }
            catch (Exception e)
            {
                _logger.Error("Failed to initialize extension. Error:{0}{1}".FormatWith(Environment.NewLine, e.ToString()));
            }

            return testingReportEventsExtensions;
        }

        private static string GetFullPath(string path)
        {
            if (!Path.IsPathRooted(path) && AppDomain.CurrentDomain.BaseDirectory != null)
            {
                path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, path);
            }

            return Path.GetFullPath(path);
        }
    }
}