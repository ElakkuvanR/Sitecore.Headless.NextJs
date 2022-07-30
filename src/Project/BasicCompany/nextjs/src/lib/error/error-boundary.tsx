import { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children?: ReactNode;
  fallBackUIComponent?: ReactNode;
}

interface State {
  hasError: boolean;
}

class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
  };

  public static getDerivedStateFromError(_: Error): State {
    // Update state so the next render will show the fallback UI.
    return { hasError: true };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
  }

  public render() {
    console.log('Has Errors ' + this.state.hasError);
    if (this.state.hasError) {
      console.log('Errors');
      return this.props.fallBackUIComponent;
    } else {
      console.log('No Errors');
    }
    return this.props.children;
  }
}

export default ErrorBoundary;
